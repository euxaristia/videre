#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include "videre.h"
#include "terminal.h"

// Mock terminal and IO for headless testing
void die(const char *s) { perror(s); exit(1); }
void editorRefreshScreen() {}
void editorSetStatusMessage(const char *fmt, ...) { (void)fmt; }
char *editorPrompt(char *prompt, void (*callback)(char *, int)) { (void)prompt; (void)callback; return NULL; }

// Global E needs to be defined since we're linking without main.o
EditorConfig E;

void test_cursor_movement() {
    initEditor();
    editorInsertRow(0, "one", 3);
    editorInsertRow(1, "two", 3);
    
    E.cy = 1; E.cx = 0;
    printf("Before move: cy=%d, numrows=%d\n", E.cy, E.numrows);
    editorMoveCursor(ARROW_DOWN);
    printf("After move: cy=%d\n", E.cy);
    assert(E.cy == 1); // Should not exceed EOF (numrows-1)
    
    E.cy = 0; E.cx = 0;
    editorMoveCursor(ARROW_UP);
    assert(E.cy == 0); // Should not exceed Top
    
    printf("test_cursor_movement passed\n");
}

void test_insertion_deletion() {
    initEditor();
    editorInsertChar('a');
    assert(E.numrows == 1);
    assert(E.row[0].size == 1);
    assert(E.row[0].chars[0] == 'a');
    
    editorDelChar();
    assert(E.row[0].size == 0);
    
    printf("test_insertion_deletion passed\n");
}

void test_delete_range() {
    initEditor();
    editorInsertRow(0, "hello world", 11);
    editorDeleteRange(0, 0, 4, 0); // Delete "hello"
    assert(E.row[0].size == 6);
    assert(strcmp(E.row[0].chars, " world") == 0);
    
    printf("test_delete_range passed\n");
}

int main() {
    test_cursor_movement();
    test_insertion_deletion();
    test_delete_range();
    printf("All C core tests passed!\n");
    return 0;
}