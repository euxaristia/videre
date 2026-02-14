package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
	"unicode"
	"unicode/utf8"
	"unsafe"
)

const (
	backspace = 1000 + iota
	arrowLeft
	arrowRight
	arrowUp
	arrowDown
	delKey
	homeKey
	endKey
	pageUp
	pageDown
	mouseEvent
	pasteEvent
	resizeEvent
)

const (
	modeNormal = iota
	modeInsert
	modeVisual
	modeVisualLine
)

const (
	hlNormal uint8 = iota
	hlComment
	hlKeyword1
	hlKeyword2
	hlString
	hlNumber
	hlMatch
	hlMatchCursor
	hlVisual
)

const (
	mouseLeft      = 0
	mouseRight     = 2
	mouseRelease   = 3
	mouseWheelUp   = 64
	mouseWheelDown = 65
	mouseDrag      = 32
)

type row struct {
	idx  int
	s    []byte
	hl   []uint8
	open bool
}

type reg struct {
	s      []byte
	isLine bool
}

type undoState struct {
	rows []row
	cx   int
	cy   int
}

type syntax struct {
	filetype string
	exts     []string
	kws      map[string]uint8
	lineCmt  string
}

type editor struct {
	cx, cy, preferred int
	rowoff, coloff    int
	screenRows        int
	screenCols        int
	rows              []row
	dirty             bool
	filename          string
	gitStatus         string
	statusmsg         string
	statusTime        time.Time
	mode              int
	selSX, selSY      int
	searchPattern     string
	searchBytes       []byte
	lastSearchChar    byte
	lastSearchDir     int
	lastSearchTill    bool
	quitWarnRemaining int
	mouseX            int
	mouseY            int
	mouseB            int
	pasteBuffer       []byte
	menuOpen          bool
	menuX             int
	menuY             int
	menuSelected      int
	isDragging        bool
	lastClickX        int
	lastClickY        int
	lastClickTime     time.Time
	marksX            [26]int
	marksY            [26]int
	markSet           [26]bool
	registers         [256]reg
	undo              []undoState
	redo              []undoState
	syntax            *syntax
	termOrig          syscall.Termios
	raw               bool
}

var E editor
var resizePending int32
var findLastMatch = -1
var findDirection = 1
var screenBuf bytes.Buffer

var syntaxes = []syntax{
	{filetype: "c", exts: []string{".c", ".h"}, kws: kwMap([]string{"if", "else", "for", "while", "switch", "case", "return", "struct|", "int|", "char|", "void|"}), lineCmt: "//"},
	{filetype: "go", exts: []string{".go"}, kws: kwMap([]string{"package", "import", "func", "type", "struct", "interface", "if", "else", "for", "range", "return", "map|", "string|", "int|", "bool|", "error|"}), lineCmt: "//"},
	{filetype: "rust", exts: []string{".rs"}, kws: kwMap([]string{"fn", "let", "mut", "if", "else", "match", "impl", "struct", "enum", "use", "pub", "String|", "Vec|"}), lineCmt: "//"},
	{filetype: "python", exts: []string{".py"}, kws: kwMap([]string{"def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "None", "True", "False"}), lineCmt: "#"},
}

func kwMap(src []string) map[string]uint8 {
	m := make(map[string]uint8, len(src))
	for _, kw := range src {
		if strings.HasSuffix(kw, "|") {
			m[strings.TrimSuffix(kw, "|")] = hlKeyword2
		} else {
			m[kw] = hlKeyword1
		}
	}
	return m
}

func die(err error) {
	disableRawMode()
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

func setStatus(format string, args ...any) {
	E.statusmsg = fmt.Sprintf(format, args...)
	E.statusTime = time.Now()
}

func validateFilename(name string) bool {
	if name == "" {
		return false
	}
	if strings.Contains(name, "..") {
		return false
	}
	if filepath.IsAbs(name) && len(name) > 4096 {
		return false
	}
	const dangerous = "<>\"|&;$`'()[]{}*?~"
	for i := 0; i < len(name); i++ {
		if strings.ContainsRune(dangerous, rune(name[i])) {
			return false
		}
	}
	if st, err := os.Stat(name); err == nil {
		if !st.Mode().IsRegular() {
			return false
		}
		if st.Size() > 100*1024*1024 {
			return false
		}
	}
	return true
}

func setSearchPattern(p string) {
	E.searchPattern = p
	if p == "" {
		E.searchBytes = nil
		return
	}
	E.searchBytes = []byte(p)
}

func getWindowSize() (int, int) {
	ws, err := ioctlGetWinsize(int(os.Stdout.Fd()), syscall.TIOCGWINSZ)
	if err == nil && ws.Col > 0 && ws.Row > 0 {
		return int(ws.Row), int(ws.Col)
	}
	return 24, 80
}

func updateWindowSize() {
	r, c := getWindowSize()
	E.screenRows = r - 2
	if E.screenRows < 1 {
		E.screenRows = 1
	}
	E.screenCols = c
}

func enableRawMode() {
	fd := int(os.Stdin.Fd())
	t, err := ioctlGetTermios(fd, syscall.TCGETS)
	if err != nil {
		return
	}
	E.termOrig = *t
	raw := *t
	raw.Iflag &^= syscall.BRKINT | syscall.ICRNL | syscall.INPCK | syscall.ISTRIP | syscall.IXON
	raw.Oflag &^= syscall.OPOST
	raw.Cflag |= syscall.CS8
	raw.Lflag &^= syscall.ECHO | syscall.ICANON | syscall.IEXTEN | syscall.ISIG
	raw.Cc[syscall.VMIN] = 0
	raw.Cc[syscall.VTIME] = 1
	if err := ioctlSetTermios(fd, syscall.TCSETS, &raw); err != nil {
		return
	}
	E.raw = true
	// Force steady block cursor for vi-like behavior and stable glyph rendering.
	fmt.Print("\x1b[?1049h\x1b[?1003h\x1b[?1006h\x1b[?2004h\x1b[2 q\x1b[2J\x1b[H")
}

func disableRawMode() {
	if !E.raw {
		return
	}
	_ = ioctlSetTermios(int(os.Stdin.Fd()), syscall.TCSETS, &E.termOrig)
	fmt.Print("\x1b[?2004l\x1b[?1006l\x1b[?1003l\x1b[0 q\x1b[?1049l\x1b[?25h")
	E.raw = false
}

func readByte(fd int) (byte, error) {
	var b [1]byte
	for {
		if atomic.SwapInt32(&resizePending, 0) != 0 {
			return 0, syscall.EINTR
		}
		n, err := syscall.Read(fd, b[:])
		if err != nil {
			if errors.Is(err, syscall.EINTR) {
				return 0, syscall.EINTR
			}
			if errors.Is(err, syscall.EAGAIN) {
				continue
			}
			return 0, err
		}
		if n == 0 {
			// Raw mode timeout; try again.
			if atomic.SwapInt32(&resizePending, 0) != 0 {
				return 0, syscall.EINTR
			}
			continue
		}
		return b[0], nil
	}
}

func readByteTimeout(fd int, maxPolls int) (byte, bool, error) {
	var b [1]byte
	polls := 0
	for polls < maxPolls {
		if atomic.SwapInt32(&resizePending, 0) != 0 {
			return 0, false, syscall.EINTR
		}
		n, err := syscall.Read(fd, b[:])
		if err != nil {
			if errors.Is(err, syscall.EINTR) {
				return 0, false, syscall.EINTR
			}
			if errors.Is(err, syscall.EAGAIN) {
				continue
			}
			return 0, false, err
		}
		if n == 0 {
			if atomic.SwapInt32(&resizePending, 0) != 0 {
				return 0, false, syscall.EINTR
			}
			polls++
			continue
		}
		return b[0], true, nil
	}
	return 0, false, nil
}

func inputReady(fd int) bool {
	var rfds syscall.FdSet
	rfds.Bits[fd/64] |= 1 << (uint(fd) % 64)
	tv := syscall.Timeval{Sec: 0, Usec: 0}
	n, err := syscall.Select(fd+1, &rfds, nil, nil, &tv)
	return err == nil && n > 0
}

func parseSGRMouse(seq []byte) (mb, mx, my int, ok bool) {
	// Expected: "<b;x;yM" or "<b;x;ym"
	if len(seq) < 6 || seq[0] != '<' {
		return 0, 0, 0, false
	}
	end := len(seq) - 1
	if seq[end] != 'M' && seq[end] != 'm' {
		return 0, 0, 0, false
	}
	part := 0
	val := 0
	haveDigit := false
	for i := 1; i < end; i++ {
		c := seq[i]
		if c >= '0' && c <= '9' {
			haveDigit = true
			val = val*10 + int(c-'0')
			continue
		}
		if c != ';' || !haveDigit {
			return 0, 0, 0, false
		}
		switch part {
		case 0:
			mb = val
		case 1:
			mx = val
		default:
			return 0, 0, 0, false
		}
		part++
		val = 0
		haveDigit = false
	}
	if part != 2 || !haveDigit {
		return 0, 0, 0, false
	}
	my = val
	return mb, mx, my, true
}

func readKey() int {
	fd := int(os.Stdin.Fd())
	first, err := readByte(fd)
	if err != nil {
		if errors.Is(err, syscall.EINTR) {
			return resizeEvent
		}
		die(err)
	}
	if first != 0x1b {
		return int(first)
	}
	if !inputReady(fd) {
		return 0x1b
	}

	// Keep plain ESC responsive (mode exit) while still allowing escape-sequence parsing.
	b, ok, err := readByteTimeout(fd, 1)
	if err != nil {
		if errors.Is(err, syscall.EINTR) {
			return resizeEvent
		}
		die(err)
	}
	if !ok {
		return 0x1b
	}

	if b == '[' {
		var seq [32]byte
		seqLen := 0
		for i := 0; i < 31; i++ {
			nb, has, rerr := readByteTimeout(fd, 1)
			if rerr != nil {
				if errors.Is(rerr, syscall.EINTR) {
					return resizeEvent
				}
				die(rerr)
			}
			if !has {
				break
			}
			seq[seqLen] = nb
			seqLen++
			if nb == '~' || nb == 'm' || nb == 'M' || (nb >= 'A' && nb <= 'Z') || (nb >= 'a' && nb <= 'z') {
				break
			}
		}
		if seqLen == 0 {
			return 0x1b
		}
		seqb := seq[:seqLen]
		// Bracketed paste start: ESC [ 200 ~
		if len(seqb) == 4 && seqb[0] == '2' && seqb[1] == '0' && seqb[2] == '0' && seqb[3] == '~' {
			var paste bytes.Buffer
			for {
				ch, rerr := readByte(fd)
				if rerr != nil {
					if errors.Is(rerr, syscall.EINTR) {
						return resizeEvent
					}
					die(rerr)
				}
				if ch == 0x1b {
					nb, has, rerr := readByteTimeout(fd, 1)
					if rerr != nil {
						die(rerr)
					}
					if has && nb == '[' {
						var endSeq [8]byte
						endLen := 0
						for i := 0; i < 5; i++ {
							b2, has2, _ := readByteTimeout(fd, 1)
							if !has2 {
								break
							}
							endSeq[endLen] = b2
							endLen++
							if b2 == '~' {
								break
							}
						}
						endb := endSeq[:endLen]
						if len(endb) == 4 && endb[0] == '2' && endb[1] == '0' && endb[2] == '1' && endb[3] == '~' {
							E.pasteBuffer = paste.Bytes()
							return pasteEvent
						}
						paste.WriteByte(0x1b)
						paste.WriteByte('[')
						paste.Write(endb)
						continue
					}
					paste.WriteByte(0x1b)
					if has {
						paste.WriteByte(nb)
					}
					continue
				}
				paste.WriteByte(ch)
			}
		}
		// SGR mouse event: ESC [ <b;x;yM / m
		if len(seqb) >= 2 && seqb[0] == '<' && (seqb[len(seqb)-1] == 'm' || seqb[len(seqb)-1] == 'M') {
			mb, mx, my, ok := parseSGRMouse(seqb)
			if ok {
				E.mouseB = mb
				E.mouseX = mx
				E.mouseY = my
				if seqb[len(seqb)-1] == 'm' {
					E.mouseB |= 0x80
				}
				return mouseEvent
			}
		}
		// CSI numeric events like 1~,3~,...
		if len(seqb) >= 2 && seqb[len(seqb)-1] == '~' && seqb[0] >= '0' && seqb[0] <= '9' {
			switch seqb[0] {
			case '1', '7':
				return homeKey
			case '3':
				return delKey
			case '4', '8':
				return endKey
			case '5':
				return pageUp
			case '6':
				return pageDown
			}
		}
		switch seqb[len(seqb)-1] {
		case 'A':
			return arrowUp
		case 'B':
			return arrowDown
		case 'C':
			return arrowRight
		case 'D':
			return arrowLeft
		case 'H':
			return homeKey
		case 'F':
			return endKey
		}
		return 0x1b
	}
	if b == 'O' {
		nb, has, rerr := readByteTimeout(fd, 1)
		if rerr != nil {
			die(rerr)
		}
		if !has {
			return 0x1b
		}
		switch nb {
		case 'H':
			return homeKey
		case 'F':
			return endKey
		}
	}
	return 0x1b
}

func utf8PrevBoundary(s []byte, idx int) int {
	if idx <= 0 {
		return 0
	}
	if idx > len(s) {
		idx = len(s)
	}
	idx--
	for idx > 0 && (s[idx]&0xC0) == 0x80 {
		idx--
	}
	return idx
}

func utf8NextBoundary(s []byte, idx int) int {
	if idx < 0 {
		return 0
	}
	if idx >= len(s) {
		return len(s)
	}
	for idx < len(s) && (s[idx]&0xC0) == 0x80 {
		idx++
	}
	if idx >= len(s) {
		return len(s)
	}
	_, n := utf8.DecodeRune(s[idx:])
	if n <= 0 {
		return idx + 1
	}
	if idx+n > len(s) {
		return len(s)
	}
	return idx + n
}

func isDigitByte(c byte) bool { return c >= '0' && c <= '9' }

func isAlphaByte(c byte) bool {
	l := c | 0x20
	return l >= 'a' && l <= 'z'
}

func isWordByte(c byte) bool { return isAlphaByte(c) || isDigitByte(c) || c == '_' }

func updateSyntax(r *row) {
	if cap(r.hl) < len(r.s) {
		r.hl = make([]uint8, len(r.s))
	} else {
		r.hl = r.hl[:len(r.s)]
		for i := range r.hl {
			r.hl[i] = hlNormal
		}
	}
	if E.syntax == nil {
		return
	}
	lineCmt := E.syntax.lineCmt
	lineCmtB := []byte(lineCmt)
	for i := 0; i < len(r.s); {
		if len(lineCmtB) > 0 && bytes.HasPrefix(r.s[i:], lineCmtB) {
			for j := i; j < len(r.s); j++ {
				r.hl[j] = hlComment
			}
			break
		}
		if r.s[i] == '"' || r.s[i] == '\'' {
			q := r.s[i]
			r.hl[i] = hlString
			i++
			for i < len(r.s) {
				r.hl[i] = hlString
				if r.s[i] == '\\' && i+1 < len(r.s) {
					i += 2
					continue
				}
				if r.s[i] == q {
					i++
					break
				}
				i++
			}
			continue
		}
		if isDigitByte(r.s[i]) {
			j := i
			for j < len(r.s) && (isDigitByte(r.s[j]) || r.s[j] == '.') {
				j++
			}
			for k := i; k < j; k++ {
				r.hl[k] = hlNumber
			}
			i = j
			continue
		}
		if isAlphaByte(r.s[i]) || r.s[i] == '_' {
			j := i
			for j < len(r.s) && isWordByte(r.s[j]) {
				j++
			}
			kw := string(r.s[i:j])
			if t, ok := E.syntax.kws[kw]; ok {
				for k := i; k < j; k++ {
					r.hl[k] = t
				}
			}
			i = j
			continue
		}
		i++
	}
	if len(E.searchBytes) > 0 {
		q := E.searchBytes
		for off := 0; ; {
			m := bytes.Index(r.s[off:], q)
			if m < 0 {
				break
			}
			m += off
			for i := m; i < m+len(q) && i < len(r.hl); i++ {
				if r.idx == E.cy && m <= E.cx && E.cx < m+len(q) {
					r.hl[i] = hlMatchCursor
				} else {
					r.hl[i] = hlMatch
				}
			}
			off = m + 1
		}
	}
}

func updateAllSyntax() {
	for i := range E.rows {
		updateSyntax(&E.rows[i])
	}
}

func selectSyntax() {
	E.syntax = nil
	if E.filename == "" {
		updateAllSyntax()
		return
	}
	ext := strings.ToLower(filepath.Ext(E.filename))
	for i := range syntaxes {
		for _, e := range syntaxes[i].exts {
			if e == ext {
				E.syntax = &syntaxes[i]
				updateAllSyntax()
				return
			}
		}
	}
	updateAllSyntax()
}

func insertRow(at int, s []byte) {
	if at < 0 || at > len(E.rows) {
		return
	}
	r := row{idx: at, s: append([]byte(nil), s...)}
	E.rows = append(E.rows, row{})
	copy(E.rows[at+1:], E.rows[at:])
	E.rows[at] = r
	for i := at; i < len(E.rows); i++ {
		E.rows[i].idx = i
	}
	updateSyntax(&E.rows[at])
	E.dirty = true
}

func delRow(at int) {
	if at < 0 || at >= len(E.rows) {
		return
	}
	E.rows = append(E.rows[:at], E.rows[at+1:]...)
	for i := at; i < len(E.rows); i++ {
		E.rows[i].idx = i
	}
	E.dirty = true
}

func rowInsertChar(r *row, at int, c byte) {
	if at < 0 || at > len(r.s) {
		at = len(r.s)
	}
	r.s = append(r.s, 0)
	copy(r.s[at+1:], r.s[at:])
	r.s[at] = c
	updateSyntax(r)
	E.dirty = true
}

func rowDelChar(r *row, at int) {
	if at < 0 || at >= len(r.s) {
		return
	}
	copy(r.s[at:], r.s[at+1:])
	r.s = r.s[:len(r.s)-1]
	updateSyntax(r)
	E.dirty = true
}

func rowAppendString(r *row, s []byte) {
	r.s = append(r.s, s...)
	updateSyntax(r)
	E.dirty = true
}

func cloneRows(src []row) []row {
	out := make([]row, len(src))
	for i := range src {
		out[i].idx = src[i].idx
		out[i].s = append([]byte(nil), src[i].s...)
		out[i].open = src[i].open
	}
	return out
}

func saveUndo() {
	s := undoState{rows: cloneRows(E.rows), cx: E.cx, cy: E.cy}
	E.undo = append(E.undo, s)
	E.redo = nil
}

func applyState(s undoState) {
	E.rows = cloneRows(s.rows)
	E.cx = s.cx
	E.cy = s.cy
	E.dirty = true
	updateAllSyntax()
}

func doUndo() {
	if len(E.undo) == 0 {
		return
	}
	E.redo = append(E.redo, undoState{rows: cloneRows(E.rows), cx: E.cx, cy: E.cy})
	last := E.undo[len(E.undo)-1]
	E.undo = E.undo[:len(E.undo)-1]
	applyState(last)
}

func doRedo() {
	if len(E.redo) == 0 {
		return
	}
	E.undo = append(E.undo, undoState{rows: cloneRows(E.rows), cx: E.cx, cy: E.cy})
	last := E.redo[len(E.redo)-1]
	E.redo = E.redo[:len(E.redo)-1]
	applyState(last)
}

func openFile(name string) {
	if !validateFilename(name) {
		setStatus("Invalid filename or path")
		return
	}
	f, err := os.Open(name)
	if err != nil {
		setStatus("Can't open file: %v", err)
		return
	}
	defer f.Close()
	E.rows = nil
	r := bufio.NewReader(f)
	for {
		line, rerr := r.ReadBytes('\n')
		if len(line) > 0 {
			if line[len(line)-1] == '\n' {
				line = line[:len(line)-1]
				if len(line) > 0 && line[len(line)-1] == '\r' {
					line = line[:len(line)-1]
				}
			}
			insertRow(len(E.rows), line)
		}
		if errors.Is(rerr, io.EOF) {
			break
		}
		if rerr != nil {
			setStatus("Read error: %v", rerr)
			break
		}
	}
	E.filename = name
	E.dirty = false
	selectSyntax()
	updateGitStatus()
}

func rowsToString() []byte {
	var b bytes.Buffer
	for i := range E.rows {
		b.Write(E.rows[i].s)
		b.WriteByte('\n')
	}
	return b.Bytes()
}

func saveFile() {
	if E.filename == "" {
		name := prompt("Save as: %s", nil)
		if name == "" {
			setStatus("Save aborted")
			return
		}
		E.filename = name
		selectSyntax()
	}
	if !validateFilename(E.filename) {
		setStatus("Invalid filename for saving")
		return
	}
	data := rowsToString()
	if err := os.WriteFile(E.filename, data, 0o644); err != nil {
		setStatus("Can't save! I/O error: %v", err)
		return
	}
	E.dirty = false
	updateGitStatus()
	setStatus("\"%s\" %dL, %dC written", E.filename, len(E.rows), len(data))
}

func updateGitStatus() {
	E.gitStatus = ""
	if E.filename == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Millisecond)
	defer cancel()
	out, err := exec.CommandContext(ctx, "git", "status", "--porcelain", "-b").Output()
	if err != nil {
		return
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) == 0 || !strings.HasPrefix(lines[0], "## ") {
		return
	}
	branch := strings.TrimPrefix(lines[0], "## ")
	if i := strings.Index(branch, "..."); i >= 0 {
		branch = branch[:i]
	}
	if len(lines) > 1 {
		branch += "*"
	}
	if len(branch) > 32 {
		branch = branch[:32]
	}
	E.gitStatus = branch
}

func insertChar(c byte) {
	saveUndo()
	if E.cy == len(E.rows) {
		insertRow(len(E.rows), nil)
	}
	rowInsertChar(&E.rows[E.cy], E.cx, c)
	E.cx = utf8NextBoundary(E.rows[E.cy].s, E.cx)
	E.preferred = E.cx
}

func insertNewline() {
	saveUndo()
	if E.cx == 0 {
		insertRow(E.cy, nil)
	} else {
		r := &E.rows[E.cy]
		insertRow(E.cy+1, r.s[E.cx:])
		r.s = append([]byte(nil), r.s[:E.cx]...)
		updateSyntax(r)
	}
	E.cy++
	E.cx = 0
	E.preferred = 0
}

func delChar() {
	if E.cy == len(E.rows) || (E.cx == 0 && E.cy == 0) {
		return
	}
	saveUndo()
	if E.cx > 0 {
		r := &E.rows[E.cy]
		prev := utf8PrevBoundary(r.s, E.cx)
		rowDelChar(r, prev)
		E.cx = prev
	} else {
		E.cx = len(E.rows[E.cy-1].s)
		rowAppendString(&E.rows[E.cy-1], E.rows[E.cy].s)
		delRow(E.cy)
		E.cy--
	}
	E.preferred = E.cx
}

func moveCursor(key int) {
	var r *row
	if E.cy >= 0 && E.cy < len(E.rows) {
		r = &E.rows[E.cy]
	}
	switch key {
	case arrowLeft:
		if E.cx > 0 && r != nil {
			E.cx = utf8PrevBoundary(r.s, E.cx)
		} else if E.cy > 0 {
			E.cy--
			E.cx = len(E.rows[E.cy].s)
			if E.mode != modeInsert && E.cx > 0 {
				E.cx = utf8PrevBoundary(E.rows[E.cy].s, E.cx)
			}
		}
	case arrowRight:
		if r != nil && E.cx < len(r.s) {
			E.cx = utf8NextBoundary(r.s, E.cx)
		} else if r != nil && E.mode == modeInsert && E.cy < len(E.rows)-1 {
			E.cy++
			E.cx = 0
		}
	case arrowUp:
		if E.cy > 0 {
			E.cy--
		}
	case arrowDown:
		if E.cy < len(E.rows)-1 {
			E.cy++
		}
	}
	if E.cy < 0 {
		E.cy = 0
	}
	if len(E.rows) == 0 {
		E.cx = 0
		return
	}
	if E.cy >= len(E.rows) {
		E.cy = len(E.rows) - 1
	}
	limit := len(E.rows[E.cy].s)
	if E.mode != modeInsert && limit > 0 {
		limit = utf8PrevBoundary(E.rows[E.cy].s, limit)
	}
	if key == arrowUp || key == arrowDown {
		if E.preferred > limit {
			E.cx = limit
		} else {
			E.cx = E.preferred
		}
	} else {
		if E.cx > limit {
			E.cx = limit
		}
		E.preferred = E.cx
	}
}

func moveLeftNoWrap() {
	if E.cy < 0 || E.cy >= len(E.rows) {
		E.cx = 0
		E.preferred = 0
		return
	}
	if E.cx > 0 {
		E.cx = utf8PrevBoundary(E.rows[E.cy].s, E.cx)
	}
	E.preferred = E.cx
}

func moveRightNoWrap() {
	if E.cy < 0 || E.cy >= len(E.rows) {
		E.cx = 0
		E.preferred = 0
		return
	}
	line := E.rows[E.cy].s
	limit := len(line)
	if E.mode != modeInsert && limit > 0 {
		limit = utf8PrevBoundary(line, limit)
	}
	if E.cx < limit {
		E.cx = utf8NextBoundary(line, E.cx)
		if E.cx > limit {
			E.cx = limit
		}
	}
	E.preferred = E.cx
}

func setClipboard(text []byte) {
	if len(text) == 0 {
		return
	}
	// OSC52 for terminals that support native clipboard.
	encoded := base64.StdEncoding.EncodeToString(text)
	fmt.Printf("\x1b]52;c;%s\x07", encoded)
	_ = os.Stdout.Sync()

	// External fallbacks.
	if cmd := exec.Command("wl-copy"); cmd != nil {
		cmd.Stdin = bytes.NewReader(text)
		_ = cmd.Run()
	}
	if cmd := exec.Command("xclip", "-selection", "clipboard"); cmd != nil {
		cmd.Stdin = bytes.NewReader(text)
		_ = cmd.Run()
	}
}

func getClipboard() []byte {
	if out, err := exec.Command("wl-paste", "-n").Output(); err == nil && len(out) > 0 {
		return out
	}
	if out, err := exec.Command("xclip", "-selection", "clipboard", "-o").Output(); err == nil && len(out) > 0 {
		return out
	}
	return nil
}

func isWordChar(c byte) bool { return isWordByte(c) }

func moveWordForward(big bool) {
	if len(E.rows) == 0 {
		return
	}
	r, c := E.cy, E.cx
	for r < len(E.rows) {
		line := E.rows[r].s
		if c < len(line) {
			if big {
				for c < len(line) && line[c] != ' ' && line[c] != '\t' {
					c++
				}
			} else {
				if isWordChar(line[c]) {
					for c < len(line) && isWordChar(line[c]) {
						c++
					}
				} else {
					for c < len(line) && !isWordChar(line[c]) && line[c] != ' ' && line[c] != '\t' {
						c++
					}
				}
			}
		}
		for c < len(line) && (line[c] == ' ' || line[c] == '\t') {
			c++
		}
		if c < len(line) {
			E.cy, E.cx, E.preferred = r, c, c
			return
		}
		r++
		c = 0
	}
	E.cy = len(E.rows) - 1
	E.cx = len(E.rows[E.cy].s)
	E.preferred = E.cx
}

func moveWordBackward(big bool) {
	if len(E.rows) == 0 {
		return
	}
	r, c := E.cy, E.cx-1
	for r >= 0 {
		line := E.rows[r].s
		for c >= 0 && (line[c] == ' ' || line[c] == '\t') {
			c--
		}
		if c >= 0 {
			if big {
				for c >= 0 && line[c] != ' ' && line[c] != '\t' {
					c--
				}
			} else {
				if isWordChar(line[c]) {
					for c >= 0 && isWordChar(line[c]) {
						c--
					}
				} else {
					for c >= 0 && !isWordChar(line[c]) && line[c] != ' ' && line[c] != '\t' {
						c--
					}
				}
			}
			E.cy, E.cx, E.preferred = r, c+1, c+1
			return
		}
		r--
		if r >= 0 {
			c = len(E.rows[r].s) - 1
		}
	}
	E.cy, E.cx, E.preferred = 0, 0, 0
}

func moveLineStart() { E.cx, E.preferred = 0, 0 }

func moveFirstNonWhitespace() {
	if E.cy < 0 || E.cy >= len(E.rows) {
		return
	}
	col := 0
	line := E.rows[E.cy].s
	for col < len(line) && (line[col] == ' ' || line[col] == '\t') {
		col++
	}
	E.cx, E.preferred = col, col
}

func moveLineEnd() {
	if E.cy >= 0 && E.cy < len(E.rows) {
		E.cx = len(E.rows[E.cy].s)
		E.preferred = E.cx
	}
}
func moveFileStart() { E.cy, E.cx, E.preferred = 0, 0, 0 }
func moveFileEnd() {
	if len(E.rows) == 0 {
		return
	}
	E.cy = len(E.rows) - 1
	E.cx = len(E.rows[E.cy].s)
	E.preferred = E.cx
}

func moveWordEnd(big bool) {
	if len(E.rows) == 0 {
		return
	}
	r, c := E.cy, E.cx+1
	for r < len(E.rows) {
		line := E.rows[r].s
		for c < len(line) && (line[c] == ' ' || line[c] == '\t') {
			c++
		}
		if c < len(line) {
			if big {
				for c < len(line)-1 && line[c+1] != ' ' && line[c+1] != '\t' {
					c++
				}
			} else {
				if isWordChar(line[c]) {
					for c < len(line)-1 && isWordChar(line[c+1]) {
						c++
					}
				} else {
					for c < len(line)-1 && !isWordChar(line[c+1]) && line[c+1] != ' ' && line[c+1] != '\t' {
						c++
					}
				}
			}
			E.cy, E.cx, E.preferred = r, c, c
			return
		}
		r++
		c = 0
	}
}

func matchBracket() {
	if E.cy < 0 || E.cy >= len(E.rows) || E.cx < 0 || E.cx >= len(E.rows[E.cy].s) {
		return
	}
	cur := E.rows[E.cy].s[E.cx]
	var target byte
	dir := 0
	switch cur {
	case '(':
		target, dir = ')', 1
	case ')':
		target, dir = '(', -1
	case '[':
		target, dir = ']', 1
	case ']':
		target, dir = '[', -1
	case '{':
		target, dir = '}', 1
	case '}':
		target, dir = '{', -1
	default:
		return
	}
	depth := 1
	ry, rx := E.cy, E.cx+dir
	for ry >= 0 && ry < len(E.rows) {
		line := E.rows[ry].s
		for rx >= 0 && rx < len(line) {
			ch := line[rx]
			if ch == cur {
				depth++
			} else if ch == target {
				depth--
				if depth == 0 {
					E.cy, E.cx, E.preferred = ry, rx, rx
					return
				}
			}
			rx += dir
		}
		ry += dir
		if dir > 0 {
			rx = 0
		} else if ry >= 0 {
			rx = len(E.rows[ry].s) - 1
		}
	}
}

func isBlankRow(idx int) bool {
	if idx < 0 || idx >= len(E.rows) {
		return true
	}
	line := E.rows[idx].s
	if len(line) == 0 {
		return true
	}
	for _, ch := range line {
		if ch != ' ' && ch != '\t' {
			return false
		}
	}
	return true
}

func movePreviousParagraph() {
	if len(E.rows) == 0 {
		return
	}
	row := E.cy
	if !isBlankRow(row) {
		for row > 0 && !isBlankRow(row-1) {
			row--
		}
	}
	for row > 0 && isBlankRow(row-1) {
		row--
	}
	for row > 0 && !isBlankRow(row-1) {
		row--
	}
	E.cy, E.cx, E.preferred = row, 0, 0
}

func moveNextParagraph() {
	if len(E.rows) == 0 {
		return
	}
	row := E.cy
	if !isBlankRow(row) {
		for row < len(E.rows)-1 && !isBlankRow(row+1) {
			row++
		}
	}
	for row < len(E.rows)-1 && isBlankRow(row+1) {
		row++
	}
	if row < len(E.rows)-1 {
		row++
	}
	E.cy, E.cx, E.preferred = row, 0, 0
}

func changeCase(toUpper bool) {
	if E.mode != modeVisual && E.mode != modeVisualLine {
		return
	}
	sy, sx := E.selSY, E.selSX
	ey, ex := E.cy, E.cx
	if sy > ey || (sy == ey && sx > ex) {
		sy, ey = ey, sy
		sx, ex = ex, sx
	}
	saveUndo()
	for y := sy; y <= ey && y < len(E.rows); y++ {
		line := E.rows[y].s
		start := 0
		end := len(line)
		if y == sy {
			start = max(0, sx)
		}
		if y == ey {
			end = min(len(line), ex+1)
		}
		for i := start; i < end; i++ {
			if toUpper {
				line[i] = byte(unicode.ToUpper(rune(line[i])))
			} else {
				line[i] = byte(unicode.ToLower(rune(line[i])))
			}
		}
		updateSyntax(&E.rows[y])
	}
	E.mode = modeNormal
	E.selSX, E.selSY = -1, -1
}

func indentSelection(indent bool) {
	if E.mode != modeVisual && E.mode != modeVisualLine {
		return
	}
	sy, ey := E.selSY, E.cy
	if sy > ey {
		sy, ey = ey, sy
	}
	saveUndo()
	for y := sy; y <= ey && y < len(E.rows); y++ {
		if indent {
			E.rows[y].s = append([]byte("    "), E.rows[y].s...)
		} else {
			trim := 0
			for trim < 4 && trim < len(E.rows[y].s) && E.rows[y].s[trim] == ' ' {
				trim++
			}
			if trim > 0 {
				E.rows[y].s = E.rows[y].s[trim:]
			}
		}
		updateSyntax(&E.rows[y])
	}
	E.mode = modeNormal
	E.selSX, E.selSY = -1, -1
}

func findChar(c byte, direction int, till bool) bool {
	E.lastSearchChar = c
	E.lastSearchDir = direction
	E.lastSearchTill = till
	if len(E.rows) == 0 {
		return false
	}
	start := E.cx
	if direction > 0 {
		start++
	} else {
		start--
	}
	if direction > 0 {
		for y := E.cy; y < len(E.rows); y++ {
			line := E.rows[y].s
			x := 0
			if y == E.cy {
				x = start
			}
			for ; x < len(line); x++ {
				if line[x] == c {
					if till {
						x--
						if x < 0 {
							x = 0
						}
					}
					E.cy, E.cx, E.preferred = y, x, x
					return true
				}
			}
		}
	} else {
		for y := E.cy; y >= 0; y-- {
			line := E.rows[y].s
			x := len(line) - 1
			if y == E.cy {
				x = start
			}
			if x >= len(line) {
				x = len(line) - 1
			}
			for ; x >= 0; x-- {
				if line[x] == c {
					if till {
						x++
						if x >= len(line) {
							x = len(line) - 1
						}
					}
					E.cy, E.cx, E.preferred = y, x, x
					return true
				}
			}
		}
	}
	return false
}

func repeatCharSearch() {
	if E.lastSearchChar == 0 {
		return
	}
	_ = findChar(E.lastSearchChar, 1, false)
}

func selectAll() {
	E.mode = modeVisual
	E.selSY, E.selSX = 0, 0
	if len(E.rows) == 0 {
		E.cy, E.cx = 0, 0
		E.preferred = 0
		return
	}
	E.cy = len(E.rows) - 1
	E.cx = len(E.rows[E.cy].s)
	E.preferred = E.cx
}

func incrementNumber(delta int) {
	if E.cy < 0 || E.cy >= len(E.rows) {
		return
	}
	line := E.rows[E.cy].s
	i := E.cx
	for i < len(line) && !(line[i] >= '0' && line[i] <= '9') {
		if line[i] == '-' && i+1 < len(line) && line[i+1] >= '0' && line[i+1] <= '9' {
			break
		}
		i++
	}
	if i >= len(line) {
		return
	}
	j := i
	if line[j] == '-' {
		j++
	}
	for j < len(line) && line[j] >= '0' && line[j] <= '9' {
		j++
	}
	n, err := strconv.Atoi(string(line[i:j]))
	if err != nil {
		return
	}
	n += delta
	saveUndo()
	repl := []byte(strconv.Itoa(n))
	newLine := make([]byte, 0, len(line)-(j-i)+len(repl))
	newLine = append(newLine, line[:i]...)
	newLine = append(newLine, repl...)
	newLine = append(newLine, line[j:]...)
	E.rows[E.cy].s = newLine
	E.cx = i + len(repl) - 1
	if E.cx < 0 {
		E.cx = 0
	}
	E.preferred = E.cx
	updateSyntax(&E.rows[E.cy])
	E.dirty = true
}

func yank(sx, sy, ex, ey int, isLine bool) {
	if sy > ey || (sy == ey && sx > ex) {
		sx, ex = ex, sx
		sy, ey = ey, sy
	}
	var b bytes.Buffer
	if isLine {
		for i := sy; i <= ey && i < len(E.rows); i++ {
			b.Write(E.rows[i].s)
			b.WriteByte('\n')
		}
	} else if sy == ey && sy < len(E.rows) {
		r := E.rows[sy].s
		if sx < 0 {
			sx = 0
		}
		if ex >= len(r) {
			ex = len(r) - 1
		}
		if sx <= ex {
			b.Write(r[sx : ex+1])
		}
	} else {
		for i := sy; i <= ey && i < len(E.rows); i++ {
			r := E.rows[i].s
			if i == sy {
				if sx < len(r) {
					b.Write(r[sx:])
				}
				b.WriteByte('\n')
			} else if i == ey {
				if ex >= len(r) {
					ex = len(r) - 1
				}
				if ex >= 0 {
					b.Write(r[:ex+1])
				}
			} else {
				b.Write(r)
				b.WriteByte('\n')
			}
		}
	}
	E.registers['"'] = reg{s: b.Bytes(), isLine: isLine}
	setClipboard(E.registers['"'].s)
}

func deleteRange(sx, sy, ex, ey int) {
	if sy > ey || (sy == ey && sx > ex) {
		sx, ex = ex, sx
		sy, ey = ey, sy
	}
	saveUndo()
	if sy == ey {
		r := &E.rows[sy]
		if sx < 0 {
			sx = 0
		}
		if ex >= len(r.s) {
			ex = len(r.s) - 1
		}
		if sx <= ex {
			r.s = append(r.s[:sx], r.s[ex+1:]...)
			updateSyntax(r)
		}
	} else {
		first := append([]byte(nil), E.rows[sy].s[:sx]...)
		if ey < len(E.rows) {
			last := E.rows[ey].s
			if ex+1 < len(last) {
				first = append(first, last[ex+1:]...)
			}
		}
		E.rows[sy].s = first
		updateSyntax(&E.rows[sy])
		for i := 0; i < ey-sy; i++ {
			delRow(sy + 1)
		}
	}
	E.cy, E.cx = sy, sx
	if E.cy >= len(E.rows) {
		E.cy = len(E.rows) - 1
	}
	if E.cy < 0 {
		E.cy = 0
	}
}

func paste() {
	if clip := getClipboard(); len(clip) > 0 {
		E.registers['"'] = reg{s: append([]byte(nil), clip...), isLine: bytes.Contains(clip, []byte{'\n'})}
	}
	r := E.registers['"']
	if len(r.s) == 0 {
		return
	}
	saveUndo()
	if r.isLine {
		lines := strings.Split(string(r.s), "\n")
		at := E.cy + 1
		for _, ln := range lines {
			if ln == "" {
				continue
			}
			insertRow(at, []byte(ln))
			at++
		}
		return
	}
	for _, c := range r.s {
		if c == '\n' {
			insertNewline()
		} else {
			insertChar(c)
		}
	}
}

func findCallback(query string, key int) {
	if key == '\r' || key == 0x1b {
		findLastMatch = -1
		findDirection = 1
		if key == 0x1b {
			setSearchPattern("")
			updateAllSyntax()
		}
		return
	}
	if key == arrowRight || key == arrowDown {
		findDirection = 1
	} else if key == arrowLeft || key == arrowUp {
		findDirection = -1
	} else {
		findLastMatch = -1
		findDirection = 1
	}
	if query == "" {
		return
	}
	if findLastMatch == -1 {
		findDirection = 1
	}
	setSearchPattern(query)
	current := findLastMatch
	for i := 0; i < len(E.rows); i++ {
		current += findDirection
		if current == -1 {
			current = len(E.rows) - 1
		} else if current == len(E.rows) {
			current = 0
		}
		p := bytes.Index(E.rows[current].s, E.searchBytes)
		if p >= 0 {
			findLastMatch = current
			E.cy = current
			E.cx = p
			E.preferred = E.cx
			E.rowoff = len(E.rows)
			break
		}
	}
	updateAllSyntax()
}

func find() {
	savedX, savedY, savedPref, savedCol, savedRow := E.cx, E.cy, E.preferred, E.coloff, E.rowoff
	q := prompt("/%s", findCallback)
	if q == "" {
		E.cx, E.cy, E.preferred, E.coloff, E.rowoff = savedX, savedY, savedPref, savedCol, savedRow
	}
}

func findNext(dir int) {
	if len(E.searchBytes) == 0 || len(E.rows) == 0 {
		return
	}
	cur := E.cy
	curCol := E.cx
	if dir > 0 {
		curCol++
	} else {
		curCol--
	}
	qLen := len(E.searchBytes)
	for i := 0; i < len(E.rows); i++ {
		cur += dir
		if cur < 0 {
			cur = len(E.rows) - 1
		}
		if cur >= len(E.rows) {
			cur = 0
		}
		line := E.rows[cur].s
		if dir > 0 {
			if cur == E.cy {
				if curCol < len(line) {
					if m := bytes.Index(line[curCol:], E.searchBytes); m >= 0 {
						m += curCol
						E.cy, E.cx, E.preferred = cur, m, m
						updateAllSyntax()
						return
					}
				}
			} else {
				if m := bytes.Index(line, E.searchBytes); m >= 0 {
					E.cy, E.cx, E.preferred = cur, m, m
					updateAllSyntax()
					return
				}
			}
		} else {
			start := len(line) - 1
			if cur == E.cy {
				start = curCol
			}
			if start >= len(line) {
				start = len(line) - 1
			}
			for x := start; x >= 0; x-- {
				if x+qLen <= len(line) && bytes.Equal(line[x:x+qLen], E.searchBytes) {
					E.cy, E.cx, E.preferred = cur, x, x
					updateAllSyntax()
					return
				}
			}
		}
	}
}

func selectWord() {
	if E.cy >= len(E.rows) || len(E.rows[E.cy].s) == 0 {
		return
	}
	r := E.rows[E.cy].s
	sx, ex := E.cx, E.cx
	for sx > 0 && isWordChar(r[sx-1]) {
		sx--
	}
	for ex < len(r)-1 && isWordChar(r[ex+1]) {
		ex++
	}
	E.mode = modeVisual
	E.selSY = E.cy
	E.selSX = sx
	E.cx = ex
}

func isSelected(filerow, x int) bool {
	if E.mode != modeVisual && E.mode != modeVisualLine {
		return false
	}
	sy, ey, sx, ex := E.selSY, E.cy, E.selSX, E.cx
	if sy > ey || (sy == ey && sx > ex) {
		sy, ey = ey, sy
		sx, ex = ex, sx
	}
	if E.mode == modeVisualLine {
		return filerow >= sy && filerow <= ey
	}
	if filerow < sy || filerow > ey {
		return false
	}
	if sy == ey {
		return x >= sx && x <= ex
	}
	if filerow == sy {
		return x >= sx
	}
	if filerow == ey {
		return x <= ex
	}
	return true
}

var syntaxColorLUT = [...]string{
	hlNormal:      "\x1b[37m",
	hlComment:     "\x1b[32m",
	hlKeyword1:    "\x1b[33m",
	hlKeyword2:    "\x1b[36m",
	hlString:      "\x1b[35m",
	hlNumber:      "\x1b[31m",
	hlMatch:       "\x1b[34m",
	hlMatchCursor: "\x1b[33m",
}

func drawRows(b *bytes.Buffer) {
	g := gutterWidth()
	gcols := 0
	if g > 0 {
		gcols = g + 1
	}
	textCols := E.screenCols - gcols
	if textCols < 1 {
		textCols = 1
	}
	hasSelection := E.mode == modeVisual || E.mode == modeVisualLine
	lineSelection := E.mode == modeVisualLine
	sy, ey, sx, ex := 0, 0, 0, 0
	if hasSelection {
		sy, ey, sx, ex = E.selSY, E.cy, E.selSX, E.cx
		if sy > ey || (sy == ey && sx > ex) {
			sy, ey = ey, sy
			sx, ex = ex, sx
		}
	}
	for y := 0; y < E.screenRows; y++ {
		fr := y + E.rowoff
		if fr >= len(E.rows) {
			if len(E.rows) == 0 && y >= E.screenRows/3 && y < E.screenRows/3+len(welcomeLines) {
				b.WriteString("\x1b[2m~\x1b[m")
				msg := welcomeLines[y-E.screenRows/3]
				if len(msg) > textCols {
					msg = msg[:textCols]
				}
				padding := (textCols - len(msg)) / 2
				for i := 0; i < padding; i++ {
					b.WriteByte(' ')
				}
				b.WriteString(msg)
			} else {
				b.WriteString("\x1b[2m~\x1b[m")
			}
		} else {
			if g > 0 {
				b.WriteString("\x1b[2m")
				n := strconv.Itoa(fr + 1)
				for i := 0; i < g-len(n); i++ {
					b.WriteByte(' ')
				}
				b.WriteString(n)
				b.WriteString(" \x1b[m")
			}
			rowData := &E.rows[fr]
			line := rowData.s
			start := E.coloff
			if start > len(line) {
				start = len(line)
			}
			hl := rowData.hl[start:]
			visible := line[start:]
			if len(visible) > textCols {
				visible = visible[:textCols]
				hl = hl[:textCols]
			}
			curColorSeq := ""
			curSelected := false
			curReverse := 0
			for i := 0; i < len(visible); i++ {
				sel := false
				if hasSelection {
					x := i + start
					if lineSelection {
						sel = fr >= sy && fr <= ey
					} else if fr >= sy && fr <= ey {
						if sy == ey {
							sel = x >= sx && x <= ex
						} else if fr == sy {
							sel = x >= sx
						} else if fr == ey {
							sel = x <= ex
						} else {
							sel = true
						}
					}
				}
				if sel != curSelected {
					if sel {
						b.WriteString("\x1b[48;5;242m")
					} else {
						b.WriteString("\x1b[49m")
					}
					curSelected = sel
				}
				h := hl[i]
				reverse := 0
				if h == hlMatch {
					reverse = 1
				} else if h == hlMatchCursor {
					reverse = 2
				}
				prevReverse := curReverse
				if reverse != curReverse {
					curReverse = reverse
					if curReverse == 1 {
						b.WriteString("\x1b[7m\x1b[48;5;94m")
					} else if curReverse == 2 {
						b.WriteString("\x1b[7m\x1b[48;5;220m")
					} else {
						b.WriteString("\x1b[27m")
					}
				}
				if curReverse == 0 {
					if prevReverse != 0 {
						// Force background re-sync after leaving reverse-video mode.
						curSelected = !sel
					}
					if sel != curSelected {
						if sel {
							b.WriteString("\x1b[48;5;242m")
						} else {
							b.WriteString("\x1b[49m")
						}
						curSelected = sel
					}
					seq := syntaxColorLUT[hlNormal]
					if int(h) < len(syntaxColorLUT) {
						seq = syntaxColorLUT[h]
					}
					if seq != curColorSeq {
						b.WriteString(seq)
						curColorSeq = seq
					}
				}
				b.WriteByte(visible[i])
			}
			b.WriteString("\x1b[27m\x1b[39m\x1b[49m")
		}
		b.WriteString("\x1b[K\r\n")
	}
}

func drawStatusBar(b *bytes.Buffer) {
	b.WriteString("\x1b[48;5;250m\x1b[38;5;240m")
	left := " [No Name]"
	if E.filename != "" {
		left = " " + E.filename
	}
	if E.dirty {
		left += " [+]"
	}
	if E.gitStatus != "" {
		left += " [" + E.gitStatus + "]"
	}
	pos := "All"
	if len(E.rows) > 0 {
		if E.rowoff == 0 {
			pos = "Top"
		} else if E.rowoff+E.screenRows >= len(E.rows) {
			pos = "Bot"
		} else {
			pos = strconv.Itoa((E.rowoff*100)/max(1, len(E.rows)-E.screenRows)) + "%"
		}
	}

	// Match C vidare ruler format: "line,col-rx" padded before Top/Bot/All/%.
	rx := 0
	if E.cy >= 0 && E.cy < len(E.rows) {
		row := E.rows[E.cy].s
		for i := 0; i < E.cx && i < len(row); {
			if row[i] == '\t' {
				rx += 8 - (rx % 8)
				i++
				continue
			}
			_, n := utf8.DecodeRune(row[i:])
			if n <= 0 {
				n = 1
			}
			rx++
			i += n
		}
	}
	loc := "0,0-1"
	if len(E.rows) > 0 {
		loc = fmt.Sprintf("%d,%d-%d", E.cy+1, E.cx+1, rx+1)
	}
	right := fmt.Sprintf(" %-14s %s", loc, pos)
	if len(left) > E.screenCols-len(right) {
		left = left[:max(0, E.screenCols-len(right))]
	}
	b.WriteString(left)
	pad := E.screenCols - len(right) - len(left)
	for i := 0; i < pad; i++ {
		b.WriteByte(' ')
	}
	b.WriteString(right)
	b.WriteString("\x1b[m\r\n")
}

func drawMessageBar(b *bytes.Buffer) {
	b.WriteString("\x1b[K")
	if E.statusmsg != "" && time.Since(E.statusTime) < 5*time.Second {
		msg := E.statusmsg
		if len(msg) > E.screenCols {
			msg = msg[:E.screenCols]
		}
		b.WriteString(msg)
		return
	}
	switch E.mode {
	case modeInsert:
		b.WriteString("-- INSERT --")
	case modeVisual:
		b.WriteString("-- VISUAL --")
	case modeVisualLine:
		b.WriteString("-- VISUAL LINE --")
	}
}

var menuItems = []string{
	" Cut       ",
	" Copy      ",
	" Paste     ",
	" Select All ",
	"----------- ",
	" Undo      ",
	" Redo      ",
}

func contextMenuInnerWidth() int {
	w := 1
	for _, item := range menuItems {
		if len(item) > w {
			w = len(item)
		}
	}
	return w
}

var welcomeLines = []string{
	"VIDERE v0.1.0",
	"",
	"videre is open source and freely distributable",
	"https://github.com/euxaristia/videre",
	"",
	"type  :q<Enter>               to exit         ",
	"type  :wq<Enter>              save and exit   ",
	"",
	"Maintainer: euxaristia",
}

func drawContextMenu(b *bytes.Buffer) {
	if !E.menuOpen {
		return
	}
	x := E.menuX
	y := E.menuY
	innerW := contextMenuInnerWidth()
	menuW := innerW + 2
	menuH := len(menuItems) + 2
	if x+menuW > E.screenCols {
		x = E.screenCols - menuW
	}
	if y+menuH > E.screenRows {
		y = E.screenRows - menuH
	}
	if x < 1 {
		x = 1
	}
	if y < 1 {
		y = 1
	}
	hline := strings.Repeat("─", innerW)
	fmt.Fprintf(b, "\x1b[%d;%dH", y, x)
	b.WriteString("\x1b[48;5;235m\x1b[38;5;239m┌" + hline + "┐")
	for i, item := range menuItems {
		fmt.Fprintf(b, "\x1b[%d;%dH", y+i+1, x)
		label := item
		if i == 4 {
			label = hline
		} else if len(label) < innerW {
			label += strings.Repeat(" ", innerW-len(label))
		} else if len(label) > innerW {
			label = label[:innerW]
		}
		if i == E.menuSelected {
			b.WriteString("\x1b[48;5;24m\x1b[38;5;255m│")
			b.WriteString(label)
			b.WriteString("│")
		} else {
			b.WriteString("\x1b[48;5;235m\x1b[38;5;239m│\x1b[38;5;252m")
			if i == 4 {
				b.WriteString("\x1b[38;5;239m")
			}
			b.WriteString(label)
			b.WriteString("\x1b[38;5;239m│")
		}
	}
	fmt.Fprintf(b, "\x1b[%d;%dH", y+len(menuItems)+1, x)
	b.WriteString("\x1b[48;5;235m\x1b[38;5;239m└" + hline + "┘\x1b[m")
}

func scroll() {
	if E.rowoff < 0 {
		E.rowoff = 0
	}
	if E.coloff < 0 {
		E.coloff = 0
	}
	if len(E.rows) == 0 {
		E.cx = 0
		E.cy = 0
		E.preferred = 0
		return
	}
	if E.cy < 0 {
		E.cy = 0
	}
	if E.cy >= len(E.rows) {
		E.cy = len(E.rows) - 1
	}
	if E.cx < 0 {
		E.cx = 0
	}
	if E.cx > len(E.rows[E.cy].s) {
		E.cx = len(E.rows[E.cy].s)
	}
	if E.rowoff >= len(E.rows) {
		E.rowoff = len(E.rows) - 1
	}

	g := gutterWidth()
	textCols := E.screenCols - g - 1
	if textCols < 1 {
		textCols = 1
	}
	if E.cy < E.rowoff {
		E.rowoff = E.cy
	}
	if E.cy >= E.rowoff+E.screenRows {
		E.rowoff = E.cy - E.screenRows + 1
	}
	if E.cx < E.coloff {
		E.coloff = E.cx
	}
	if E.cx >= E.coloff+textCols {
		E.coloff = E.cx - textCols + 1
	}
}

func byteIndexFromDisplayCol(s []byte, target int) int {
	if target <= 0 {
		return 0
	}
	i := 0
	col := 0
	for i < len(s) {
		if s[i] == '\t' {
			step := 8 - (col % 8)
			if col+step > target {
				break
			}
			col += step
			i++
			continue
		}
		if s[i] < utf8.RuneSelf {
			if col+1 > target {
				break
			}
			col++
			i++
			continue
		}
		_, n := utf8.DecodeRune(s[i:])
		if n <= 0 {
			n = 1
		}
		if col+1 > target {
			break
		}
		col++
		i += n
	}
	return i
}

func displayWidthBytes(s []byte) int {
	col := 0
	for i := 0; i < len(s); {
		if s[i] == '\t' {
			col += 8 - (col % 8)
			i++
			continue
		}
		if s[i] < utf8.RuneSelf {
			col++
			i++
			continue
		}
		_, n := utf8.DecodeRune(s[i:])
		if n <= 0 {
			n = 1
		}
		col++
		i += n
	}
	return col
}

func executeMenuAction(idx int) {
	switch idx {
	case 0: // Cut
		if E.mode == modeVisual || E.mode == modeVisualLine {
			yank(E.selSX, E.selSY, E.cx, E.cy, E.mode == modeVisualLine)
			deleteRange(E.selSX, E.selSY, E.cx, E.cy)
			E.mode = modeNormal
			E.selSX, E.selSY = -1, -1
		}
	case 1: // Copy
		if E.mode == modeVisual || E.mode == modeVisualLine {
			yank(E.selSX, E.selSY, E.cx, E.cy, E.mode == modeVisualLine)
			E.mode = modeNormal
			E.selSX, E.selSY = -1, -1
		}
	case 2: // Paste
		paste()
	case 3: // Select All
		selectAll()
	case 5: // Undo
		doUndo()
	case 6: // Redo
		doRedo()
	}
}

func handleMouse() bool {
	b := E.mouseB
	x := E.mouseX
	y := E.mouseY

	if E.menuOpen {
		prevSelected := E.menuSelected
		menuW := contextMenuInnerWidth() + 2
		menuH := len(menuItems) + 2
		mx, my := E.menuX, E.menuY
		if mx+menuW > E.screenCols {
			mx = E.screenCols - menuW
		}
		if my+menuH > E.screenRows {
			my = E.screenRows - menuH
		}
		if mx < 1 {
			mx = 1
		}
		if my < 1 {
			my = 1
		}
		if x >= mx && x < mx+menuW && y >= my && y < my+menuH {
			E.menuSelected = y - my - 1
			if E.menuSelected < 0 || E.menuSelected >= len(menuItems) {
				E.menuSelected = -1
			}
		} else {
			E.menuSelected = -1
		}
		if b == mouseLeft {
			if E.menuSelected >= 0 {
				executeMenuAction(E.menuSelected)
			}
			E.menuOpen = false
			return true
		}
		if b == mouseRight {
			E.menuX, E.menuY = x, y
			E.menuSelected = -1
			return true
		}
		if b&0x80 != 0 || b&mouseDrag != 0 || b == mouseRelease {
			return E.menuSelected != prevSelected
		}
		E.menuOpen = false
		return true
	}

	if b&0x40 != 0 {
		if (b&0x3) == 0 || b == mouseWheelUp {
			for i := 0; i < 3; i++ {
				if E.rowoff > 0 {
					E.rowoff--
					if E.cy > 0 {
						E.cy--
					}
				}
			}
		} else if (b&0x3) == 1 || b == mouseWheelDown {
			for i := 0; i < 3; i++ {
				if E.rowoff+E.screenRows < len(E.rows) {
					E.rowoff++
					if E.cy < len(E.rows)-1 {
						E.cy++
					}
				}
			}
		}
		E.preferred = E.cx
		return true
	}

	if b == mouseRight {
		E.menuOpen = true
		E.menuX = x
		E.menuY = y
		E.menuSelected = -1
		return true
	}

	if b&0x80 != 0 || (b&0x3) == mouseRelease {
		E.isDragging = false
		return false
	}
	if b != mouseLeft && b != (mouseLeft|mouseDrag) {
		// Ignore pure motion/unknown button states and ensure dragging doesn't stick.
		E.isDragging = false
		return false
	}
	prevCX, prevCY := E.cx, E.cy

	applyMousePosition := func() bool {
		if len(E.rows) == 0 {
			return false
		}
		fr := y - 1 + E.rowoff
		if fr < 0 || fr >= len(E.rows) {
			return false
		}
		E.cy = fr
		g := gutterWidth()
		gcols := 0
		if g > 0 {
			gcols = g + 1
		}
		textX := x - gcols
		target := 0
		if textX > 1 {
			target = textX - 1
		}
		start := E.coloff
		if start > len(E.rows[E.cy].s) {
			start = len(E.rows[E.cy].s)
		}
		rel := byteIndexFromDisplayCol(E.rows[E.cy].s[start:], target)
		E.cx = start + rel
		if E.mode != modeInsert && len(E.rows[E.cy].s) > 0 && E.cx >= len(E.rows[E.cy].s) {
			E.cx = len(E.rows[E.cy].s) - 1
		}
		E.preferred = E.cx
		return true
	}

	if b == (mouseLeft | mouseDrag) {
		if !E.isDragging {
			return false
		}
		if !applyMousePosition() {
			return false
		}
		if E.mode == modeNormal {
			E.mode = modeVisual
		}
		return true
	}

	if b == mouseLeft {
		if !applyMousePosition() {
			return false
		}
		now := time.Now()
		doubleClick := x == E.lastClickX && y == E.lastClickY &&
			!E.lastClickTime.IsZero() && now.Sub(E.lastClickTime) < 500*time.Millisecond

		if doubleClick {
			selectWord()
			E.isDragging = false
			if E.mode != modeVisual && E.mode != modeVisualLine {
				E.mode = modeVisual
			}
		} else {
			E.isDragging = true
			E.selSX = E.cx
			E.selSY = E.cy
			if E.mode == modeVisual || E.mode == modeVisualLine {
				E.mode = modeNormal
				E.selSX, E.selSY = -1, -1
			}
		}
		E.lastClickX = x
		E.lastClickY = y
		E.lastClickTime = now
		return true
	}
	return E.cx != prevCX || E.cy != prevCY
}

func refreshScreen() {
	scroll()
	screenBuf.Reset()
	screenBuf.WriteString("\x1b[?25l\x1b[H")
	drawRows(&screenBuf)
	drawStatusBar(&screenBuf)
	drawMessageBar(&screenBuf)
	drawContextMenu(&screenBuf)
	g := gutterWidth()
	curRow := (E.cy - E.rowoff) + 1
	if curRow < 1 {
		curRow = 1
	}
	curCol := 1 + g + 1
	if E.cy >= 0 && E.cy < len(E.rows) {
		line := E.rows[E.cy].s
		start := E.coloff
		if start > len(line) {
			start = len(line)
		}
		end := E.cx
		if end > len(line) {
			end = len(line)
		}
		if end < start {
			end = start
		}
		curCol += displayWidthBytes(line[start:end])
	}
	if curCol < 1 {
		curCol = 1
	}
	if len(E.statusmsg) > 0 && E.statusmsg[0] == ':' {
		curRow = E.screenRows + 2
		curCol = len(E.statusmsg) + 1
	}
	fmt.Fprintf(&screenBuf, "\x1b[%d;%dH", curRow, curCol)
	screenBuf.WriteString("\x1b[?25h")
	_, _ = os.Stdout.Write(screenBuf.Bytes())
}

func gutterWidth() int {
	if E.filename == "" && len(E.rows) == 0 {
		return 0
	}
	n := max(1, len(E.rows))
	w := 1
	for n >= 10 {
		n /= 10
		w++
	}
	return w
}

func prompt(p string, cb func(string, int)) string {
	buf := make([]byte, 0, 128)
	for {
		setStatus(p, string(buf))
		refreshScreen()
		c := readKey()
		switch c {
		case delKey, backspace, 127, 8:
			if len(buf) > 0 {
				buf = buf[:len(buf)-1]
			}
		case 0x1b:
			setStatus("")
			if cb != nil {
				cb(string(buf), c)
			}
			return ""
		case '\r':
			if len(buf) > 0 {
				setStatus("")
				if cb != nil {
					cb(string(buf), c)
				}
				return string(buf)
			}
		default:
			if c >= 32 && c < 128 {
				buf = append(buf, byte(c))
			}
		}
		if cb != nil {
			cb(string(buf), c)
		}
	}
}

func processKeypress() bool {
	c := readKey()
	if c == -1 {
		return false
	}
	if c == resizeEvent {
		updateWindowSize()
		return true
	}
	if E.menuOpen && c != mouseEvent {
		E.menuOpen = false
		if c == 0x1b {
			return true
		}
	}
	if c == mouseEvent {
		return handleMouse()
	}
	if c == pasteEvent {
		if len(E.pasteBuffer) > 0 {
			for i := 0; i < len(E.pasteBuffer); i++ {
				ch := E.pasteBuffer[i]
				if ch == '\r' || ch == '\n' {
					insertNewline()
					if ch == '\r' && i+1 < len(E.pasteBuffer) && E.pasteBuffer[i+1] == '\n' {
						i++
					}
				} else {
					insertChar(ch)
				}
			}
			E.pasteBuffer = nil
		}
		return true
	}
	if E.mode == modeInsert {
		switch c {
		case '\r':
			insertNewline()
		case 0x1b:
			E.mode = modeNormal
			if E.cx > 0 {
				E.cx--
			}
			setStatus("")
		case backspace, 127, 8:
			delChar()
		case delKey:
			moveCursor(arrowRight)
			delChar()
		case arrowLeft, arrowRight, arrowUp, arrowDown:
			moveCursor(c)
		default:
			if c >= 32 && c <= 255 && c != 127 {
				insertChar(byte(c))
			}
		}
		return true
	}

	switch c {
	case 'i':
		E.mode = modeInsert
		E.selSX, E.selSY = -1, -1
		setStatus("-- INSERT --")
	case 'v':
		if E.mode == modeVisual {
			E.mode = modeNormal
			E.selSX, E.selSY = -1, -1
		} else {
			E.mode = modeVisual
			E.selSX, E.selSY = E.cx, E.cy
		}
	case 'V':
		if E.mode == modeVisualLine {
			E.mode = modeNormal
			E.selSX, E.selSY = -1, -1
		} else {
			E.mode = modeVisualLine
			E.selSX, E.selSY = 0, E.cy
		}
	case 'u':
		if E.mode == modeVisual || E.mode == modeVisualLine {
			changeCase(false)
		} else {
			doUndo()
		}
	case 18:
		doRedo()
	case 1:
		incrementNumber(1)
	case 24:
		incrementNumber(-1)
	case 'U':
		if E.mode == modeVisual || E.mode == modeVisualLine {
			changeCase(true)
		}
	case 'y':
		if E.mode == modeVisual || E.mode == modeVisualLine {
			yank(E.selSX, E.selSY, E.cx, E.cy, E.mode == modeVisualLine)
			E.mode = modeNormal
			E.selSX, E.selSY = -1, -1
		}
	case 'd', 'x':
		if E.mode == modeVisual || E.mode == modeVisualLine {
			yank(E.selSX, E.selSY, E.cx, E.cy, E.mode == modeVisualLine)
			deleteRange(E.selSX, E.selSY, E.cx, E.cy)
			E.mode = modeNormal
			E.selSX, E.selSY = -1, -1
		} else if c == 'x' {
			moveCursor(arrowRight)
			delChar()
		}
	case 'p':
		paste()
	case 3:
		if E.dirty && E.quitWarnRemaining > 0 {
			setStatus("WARNING!!! File has unsaved changes. Press Ctrl-C %d more times to quit.", E.quitWarnRemaining)
			E.quitWarnRemaining--
			return true
		}
		disableRawMode()
		os.Exit(0)
	case ':':
		cmd := prompt(":%s", nil)
		switch cmd {
		case "q":
			if E.dirty {
				setStatus("No write since last change (add ! to override)")
			} else {
				disableRawMode()
				os.Exit(0)
			}
		case "q!":
			disableRawMode()
			os.Exit(0)
		case "w":
			saveFile()
		case "wq":
			saveFile()
			disableRawMode()
			os.Exit(0)
		default:
			if cmd != "" {
				setStatus("Not an editor command: %s", cmd)
			}
		}
	case '/':
		find()
	case 'n':
		findNext(1)
	case 'N':
		findNext(-1)
	case 'h':
		moveLeftNoWrap()
	case 'j':
		moveCursor(arrowDown)
	case 'k':
		moveCursor(arrowUp)
	case 'l':
		moveRightNoWrap()
	case arrowLeft, arrowRight, arrowUp, arrowDown:
		moveCursor(c)
	case homeKey:
		E.cx = 0
	case '0':
		moveLineStart()
	case '^':
		moveFirstNonWhitespace()
	case endKey:
		if E.cy >= 0 && E.cy < len(E.rows) {
			E.cx = len(E.rows[E.cy].s)
		}
	case '$':
		moveLineEnd()
	case pageUp, pageDown:
		if c == pageUp {
			E.cy = E.rowoff
		} else {
			E.cy = E.rowoff + E.screenRows - 1
			if E.cy > len(E.rows) {
				E.cy = len(E.rows)
			}
		}
		for i := 0; i < E.screenRows; i++ {
			if c == pageUp {
				moveCursor(arrowUp)
			} else {
				moveCursor(arrowDown)
			}
		}
	case 'w':
		moveWordForward(false)
	case 'W':
		moveWordForward(true)
	case 'b':
		moveWordBackward(false)
	case 'B':
		moveWordBackward(true)
	case 'e':
		moveWordEnd(false)
	case 'E':
		moveWordEnd(true)
	case 'g':
		if readKey() == 'g' {
			moveFileStart()
		}
	case 'G':
		moveFileEnd()
	case 'm':
		m := readKey()
		if m >= 'a' && m <= 'z' {
			i := m - 'a'
			E.markSet[i] = true
			E.marksX[i] = E.cx
			E.marksY[i] = E.cy
		}
	case '\'':
		m := readKey()
		if m >= 'a' && m <= 'z' {
			i := m - 'a'
			if E.markSet[i] {
				if len(E.rows) == 0 {
					E.cy, E.cx = 0, 0
				} else {
					E.cy = min(max(0, E.marksY[i]), len(E.rows)-1)
					E.cx = min(E.marksX[i], len(E.rows[E.cy].s))
				}
				E.preferred = E.cx
			} else {
				setStatus("E20: Mark not set")
			}
		}
	case '%':
		matchBracket()
	case '{':
		movePreviousParagraph()
	case '}':
		moveNextParagraph()
	case '>':
		indentSelection(true)
	case '<':
		indentSelection(false)
	case 'f', 'F', 't', 'T':
		n := readKey()
		if n >= 32 && n <= 255 && n != 127 {
			dir := 1
			if c == 'F' || c == 'T' {
				dir = -1
			}
			till := c == 't' || c == 'T'
			_ = findChar(byte(n), dir, till)
			setStatus("Found %c at %d,%d", n, E.cy+1, E.cx+1)
		}
	case ';':
		repeatCharSearch()
	case ',':
		if E.lastSearchChar != 0 {
			_ = findChar(E.lastSearchChar, -1, false)
		}
	case 0x1b:
		E.mode = modeNormal
		E.selSX, E.selSY = -1, -1
		setStatus("")
	}
	E.quitWarnRemaining = 1
	return true
}

func initEditor() {
	E = editor{mode: modeNormal, selSX: -1, selSY: -1, quitWarnRemaining: 1, menuSelected: -1}
	updateWindowSize()
}

func main() {
	defer func() {
		if r := recover(); r != nil {
			disableRawMode()
			fmt.Fprintf(os.Stderr, "videre-go panic: %v\n", r)
			_, _ = os.Stderr.Write(debug.Stack())
			os.Exit(2)
		}
	}()

	initEditor()
	if _, err := ioctlGetTermios(int(os.Stdin.Fd()), syscall.TCGETS); err != nil {
		fmt.Fprintln(os.Stderr, "videre-go requires a TTY on stdin")
		os.Exit(1)
	}
	if _, err := ioctlGetWinsize(int(os.Stdout.Fd()), syscall.TIOCGWINSZ); err != nil {
		fmt.Fprintln(os.Stderr, "videre-go requires a TTY on stdout")
		os.Exit(1)
	}
	enableRawMode()
	defer disableRawMode()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGWINCH)
	go func() {
		for range sig {
			updateWindowSize()
			atomic.StoreInt32(&resizePending, 1)
		}
	}()

	args := os.Args[1:]
	if len(args) > 0 && args[0] == "--" {
		args = args[1:]
	}
	if len(args) >= 1 {
		openFile(args[0])
		E.filename = args[0]
	}

	refreshScreen()
	for {
		if processKeypress() {
			refreshScreen()
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

type winsize struct {
	Row    uint16
	Col    uint16
	Xpixel uint16
	Ypixel uint16
}

func ioctlGetWinsize(fd int, req uintptr) (*winsize, error) {
	ws := &winsize{}
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), req, uintptr(unsafe.Pointer(ws)))
	if errno != 0 {
		return nil, errno
	}
	return ws, nil
}

func ioctlGetTermios(fd int, req uintptr) (*syscall.Termios, error) {
	t := &syscall.Termios{}
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), req, uintptr(unsafe.Pointer(t)))
	if errno != 0 {
		return nil, errno
	}
	return t, nil
}

func ioctlSetTermios(fd int, req uintptr, t *syscall.Termios) error {
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), req, uintptr(unsafe.Pointer(t)))
	if errno != 0 {
		return errno
	}
	return nil
}
