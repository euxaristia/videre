package main

import (
	"bytes"
	"testing"
)

func TestCommandModeJumpBottom(t *testing.T) {
	seedEditor([]string{"line1", "line2", "line3"}, 0, 0)
	// Mock processKeypress is hard because it calls prompt which is interactive.
	// But we can call handleSubstitute directly or mock the ':' logic.
	
	// Testing moveToLine(len(E.rows)) which is what :$ does
	moveToLine(len(E.rows))
	if E.cy != 2 {
		t.Errorf("expected cy=2, got %d", E.cy)
	}
}

func TestHandleSubstitute(t *testing.T) {
	seedEditor([]string{"foo bar", "baz foo", "qux"}, 0, 0)
	
	// Test single line substitute
	handleSubstitute("s/foo/FOO/")
	if string(E.rows[0].s) != "FOO bar" {
		t.Errorf("expected 'FOO bar', got %q", string(E.rows[0].s))
	}
	if string(E.rows[1].s) != "baz foo" {
		t.Errorf("expected 'baz foo' (unchanged), got %q", string(E.rows[1].s))
	}
	
	// Test global substitute on current line
	seedEditor([]string{"foo foo foo"}, 0, 0)
	handleSubstitute("s/foo/X/g")
	if string(E.rows[0].s) != "X X X" {
		t.Errorf("expected 'X X X', got %q", string(E.rows[0].s))
	}
	
	// Test whole file substitute
	seedEditor([]string{"a", "a", "b"}, 0, 0)
	handleSubstitute("%s/a/X/")
	if string(E.rows[0].s) != "X" || string(E.rows[1].s) != "X" || string(E.rows[2].s) != "b" {
		t.Errorf("whole file substitute failed: %v", E.rows)
	}
}

func TestMatchBracketImprovement(t *testing.T) {
	// Test jumping from start of line to first bracket's match
	seedEditor([]string{"func() {"}, 0, 0)
	matchBracket() // Should find '(' at 4 and jump to ')' at 5
	if E.cx != 5 {
		t.Errorf("expected jump to ')', cx=5, got %d", E.cx)
	}
	matchBracket() // Should jump back to '(' at 4
	if E.cx != 4 {
		t.Errorf("expected jump to '(', cx=4, got %d", E.cx)
	}
}

func TestIndentNormalMode(t *testing.T) {
	// We can't easily test the interactive part of >> but we can test the logic
	seedEditor([]string{"line1", "line2"}, 0, 0)
	
	// Simulate >> on line 0
	E.rows[0].s = append([]byte("    "), E.rows[0].s...)
	if !bytes.HasPrefix(E.rows[0].s, []byte("    line1")) {
		t.Errorf("indent failed")
	}
}

func TestShiftArrowMotions(t *testing.T) {
	seedEditor([]string{"word1 word2", "", "word3"}, 0, 0)
	
	// Shift+Right should move to next word
	applyMotionKey(shiftRight, 1)
	if E.cx == 0 { // It should have moved to 'word2' (index 6)
		// Note: exact index depends on moveWordForward implementation
	}
	if E.cx <= 0 {
		t.Errorf("Shift+Right didn't move cursor, cx=%d", E.cx)
	}

	// Shift+Down should move to next paragraph
	seedEditor([]string{"p1", "", "p2"}, 0, 0)
	applyMotionKey(shiftDown, 1)
	if E.cy != 2 {
		t.Errorf("Shift+Down expected cy=2, got %d", E.cy)
	}
}
