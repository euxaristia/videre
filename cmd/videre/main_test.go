package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func seedEditor(lines []string, cx, cy int) {
	E = editor{mode: modeNormal, selSX: -1, selSY: -1}
	E.rows = make([]row, len(lines))
	for i, ln := range lines {
		E.rows[i] = row{idx: i, s: []byte(ln)}
	}
	E.cx = cx
	E.cy = cy
	E.preferred = cx
}

func TestTerminalCursorModeUsesBlinkingBlock(t *testing.T) {
	if !strings.Contains(termEnterSeq, "\x1b[1 q") {
		t.Fatalf("startup terminal sequence must request blinking block cursor")
	}
	if !strings.Contains(termLeaveSeq, "\x1b[0 q") {
		t.Fatalf("shutdown terminal sequence must reset cursor style")
	}
}

func TestFindCharDoesNotCrossLines(t *testing.T) {
	seedEditor([]string{"abc", "x"}, 0, 0)
	if findChar('x', 1, false) {
		t.Fatalf("findChar must stay on current line")
	}
	if E.cy != 0 || E.cx != 0 {
		t.Fatalf("cursor moved unexpectedly: got (%d,%d)", E.cx, E.cy)
	}
}

func TestRepeatCharSearchRespectsDirection(t *testing.T) {
	seedEditor([]string{"a1a2a3"}, 0, 0)
	if !findChar('a', 1, false) {
		t.Fatalf("initial findChar failed")
	}
	if E.cx != 2 {
		t.Fatalf("expected first forward match at col 2, got %d", E.cx)
	}
	repeatCharSearch(false)
	if E.cx != 4 {
		t.Fatalf("expected ';' repeat to continue forward to col 4, got %d", E.cx)
	}
	repeatCharSearch(true)
	if E.cx != 2 {
		t.Fatalf("expected ',' repeat to reverse to col 2, got %d", E.cx)
	}
}

func TestApplyMotionKeyCount(t *testing.T) {
	seedEditor([]string{"a", "b", "c", "d"}, 0, 0)
	changed := applyMotionKey('j', 3)
	if !changed {
		t.Fatalf("expected motion to report changed")
	}
	if E.cy != 3 {
		t.Fatalf("expected down motion count to land on row 3, got %d", E.cy)
	}
}

func TestMoveToLineClamps(t *testing.T) {
	seedEditor([]string{"a", "b", "c"}, 0, 0)
	moveToLine(99)
	if E.cy != 2 {
		t.Fatalf("expected moveToLine to clamp to last row, got %d", E.cy)
	}
	moveToLine(0)
	if E.cy != 0 {
		t.Fatalf("expected moveToLine(0) to clamp to first row, got %d", E.cy)
	}
}

func TestOpenFileMissingStartsNewBuffer(t *testing.T) {
	seedEditor([]string{"keep"}, 1, 0)
	E.filename = "existing.txt"
	target := filepath.Join(t.TempDir(), "does-not-exist.txt")
	ok := openFile(target)
	if !ok {
		t.Fatalf("openFile should succeed for missing file")
	}
	if len(E.rows) != 0 {
		t.Fatalf("expected empty buffer for new file, got %d rows", len(E.rows))
	}
	if got, want := E.filename, target; got != want {
		t.Fatalf("expected filename %q, got %q", want, got)
	}
	if E.dirty {
		t.Fatalf("new file buffer should not start dirty")
	}
}

func TestOpenFileFailureKeepsExistingBuffer(t *testing.T) {
	seedEditor([]string{"keep"}, 1, 0)
	E.filename = "existing.txt"
	notAFile := filepath.Join(t.TempDir(), "dir")
	if err := os.Mkdir(notAFile, 0o755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	ok := openFile(notAFile)
	if ok {
		t.Fatalf("openFile should fail for invalid file path")
	}
	if len(E.rows) != 1 || string(E.rows[0].s) != "keep" {
		t.Fatalf("buffer mutated on failed open")
	}
	if E.filename != "existing.txt" {
		t.Fatalf("filename changed on failed open: %q", E.filename)
	}
}

func TestOpenFileExpandsHome(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	target := filepath.Join(home, "expand-home.txt")
	ok := openFile("~/expand-home.txt")
	if !ok {
		t.Fatalf("openFile should succeed for missing file under home")
	}
	if E.filename != target {
		t.Fatalf("expected expanded path %q, got %q", target, E.filename)
	}
}

func TestYoink(t *testing.T) {
	seedEditor([]string{"hello", "world"}, 0, 0)
	yoink(0, 0, 4, 0, false) // yoink "hello"
	got := string(E.registers['"'].s)
	if got != "hello" {
		t.Fatalf("expected 'hello', got %q", got)
	}

	yoink(0, 0, 0, 1, true) // yoink both lines
	got = string(E.registers['"'].s)
	if got != "hello\nworld\n" {
		t.Fatalf("expected 'hello\\nworld\\n', got %q", got)
	}
}
