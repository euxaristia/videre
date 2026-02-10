#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>

// Mock the global editor state for testing
typedef struct {
    int cx, cy;
    int numrows;
    void *row;
    char *filename;
    char *search_pattern;
    int dirty;
} MockEditor;

MockEditor E = {0};

// Mock implementations
void die(const char *s) {
    fprintf(stderr, "DIE: %s\n", s);
}

void editorSetStatusMessage(const char *fmt, ...) {
    // Mock implementation
}

char *editorPrompt(char *prompt, void (*callback)(char *, int)) {
    return strdup("test");
}

// Mock terminal functions
void disableRawMode() {}
void enableRawMode() {}
int readKey() { return 0; }
int getWindowSize(int *rows, int *cols) { *rows = 24; *cols = 80; return 0; }

// Mock editor functions
void initEditor() {
    memset(&E, 0, sizeof(E));
}

void editorOpen(char *filename) {
    if (E.filename) free(E.filename);
    E.filename = strdup(filename);
    E.numrows = 1;
}

void editorInsertChar(int c) {
    // Mock implementation
}

void editorMoveCursor(int key) {
    // Mock implementation
}

void editorDelChar() {
    // Mock implementation
}

void editorInsertNewline() {
    // Mock implementation
}

void editorUndo() {
    // Mock implementation
}

void editorRedo() {
    // Mock implementation
}

void editorFreeRow(void *row) {
    // Mock implementation
}

void editorUpdateSyntax(void *row) {
    // Mock implementation
}

void editorSelectSyntaxHighlight() {
    // Mock implementation
}

// Fuzz target function
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // Initialize editor state
    initEditor();
    
    // Create temporary file with fuzz data
    char temp_file[] = "/tmp/fuzz_input_XXXXXX";
    int fd = mkstemp(temp_file);
    if (fd == -1) return 0;
    
    // Write fuzz data to temp file
    write(fd, data, size);
    close(fd);
    
    // Test file operations with fuzz data
    editorOpen(temp_file);
    
    // Test editing operations
    if (size > 0) {
        // Insert some characters from fuzz data
        for (size_t i = 0; i < size && i < 100; i++) {
            editorInsertChar(data[i % 128]);
        }
        
        // Test cursor movement
        editorMoveCursor(1001); // ARROW_LEFT
        editorMoveCursor(1002); // ARROW_RIGHT
        editorMoveCursor(1003); // ARROW_UP
        editorMoveCursor(1004); // ARROW_DOWN
        
        // Test deletion
        editorDelChar();
        
        // Test newline insertion
        editorInsertNewline();
    }
    
    // Test undo/redo
    editorUndo();
    editorRedo();
    
    // Cleanup
    unlink(temp_file);
    
    // Cleanup editor state
    if (E.filename) free(E.filename);
    if (E.search_pattern) free(E.search_pattern);
    
    return 0;
}