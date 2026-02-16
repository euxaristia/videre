package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func generateBenchmarkFile(b *testing.B, lines int) string {
	b.Helper()
	dir := b.TempDir()
	path := filepath.Join(dir, fmt.Sprintf("bench_%d.txt", lines))
	f, err := os.Create(path)
	if err != nil {
		b.Fatal(err)
	}
	for i := 0; i < lines; i++ {
		fmt.Fprintf(f, "Line %d: The quick brown fox jumps over the lazy dog.\n", i+1)
	}
	f.Close()
	return path
}

func BenchmarkVidereOpenFile(b *testing.B) {
	cases := []struct {
		name  string
		lines int
	}{
		{"Empty", 0},
		{"100", 100},
		{"1K", 1000},
		{"10K", 10000},
	}

	for _, tc := range cases {
		path := generateBenchmarkFile(b, tc.lines)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			openFile(path)
		}
	}
}

func BenchmarkVidereInsertChar(b *testing.B) {
	seedEditor([]string{""}, 0, 0)
	E.mode = modeInsert
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		insertChar('a')
		if len(E.rows[0].s) > 1000 {
			seedEditor([]string{""}, 0, 0)
			E.mode = modeInsert
		}
	}
}

func BenchmarkVidereInsertNewline(b *testing.B) {
	seedEditor([]string{""}, 0, 0)
	E.mode = modeInsert
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		insertNewline()
		if len(E.rows) > 1000 {
			seedEditor([]string{""}, 0, 0)
			E.mode = modeInsert
		}
	}
}

func BenchmarkVidereMovement(b *testing.B) {
	lines := make([]string, 1000)
	for i := range lines {
		lines[i] = "The quick brown fox jumps over the lazy dog."
	}
	
	b.Run("DownUp", func(b *testing.B) {
		seedEditor(lines, 0, 0)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			moveCursor(arrowDown)
			if E.cy >= len(E.rows)-1 {
				E.cy = 0
			}
			moveCursor(arrowUp)
		}
	})

	b.Run("WordForward", func(b *testing.B) {
		seedEditor(lines, 0, 0)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			moveWordForward(false)
			if E.cy >= len(E.rows)-1 {
				E.cy = 0
				E.cx = 0
			}
		}
	})

	b.Run("WordBackward", func(b *testing.B) {
		seedEditor(lines, 0, 999)
		E.cx = len(E.rows[E.cy].s)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			moveWordBackward(false)
			if E.cy <= 0 && E.cx <= 0 {
				E.cy = 999
				E.cx = len(E.rows[E.cy].s)
			}
		}
	})
}

func BenchmarkVidereDrawRows(b *testing.B) {
	lines := make([]string, 1000)
	for i := range lines {
		lines[i] = "func BenchmarkDrawRows(b *testing.B) { // Some comment"
	}
	seedEditor(lines, 0, 0)
	E.screenRows = 24
	E.screenCols = 80
	E.filename = "test.go"
	selectSyntax()
	
	var buf bytes.Buffer
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		buf.Reset()
		drawRows(&buf)
	}
}

func BenchmarkVidereSaveFile(b *testing.B) {
	lines := make([]string, 1000)
	for i := range lines {
		lines[i] = "The quick brown fox jumps over the lazy dog."
	}
	seedEditor(lines, 0, 0)
	
	dir := b.TempDir()
	E.filename = filepath.Join(dir, "save_test.txt")
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		saveFile()
	}
}
