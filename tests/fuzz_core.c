#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include "videre.h"

// Prototypes for functions we'll wrap or use from linked objects
void initEditor();
int editorProcessKeypress();

// Global pointer to fuzz data for mocking readKey
static const uint8_t *fuzz_data;
static size_t fuzz_size;
static size_t fuzz_offset;

// Linker wraps
void __wrap_enableRawMode() {}
void __wrap_disableRawMode() {}
int __wrap_getWindowSize(int *rows, int *cols) {
    *rows = 24;
    *cols = 80;
    return 0;
}
void __wrap_editorRefreshScreen() {}

int __wrap_readKey() {
    if (fuzz_offset < fuzz_size) {
        return fuzz_data[fuzz_offset++];
    }
    return '\x1b'; // Return ESC to abort prompts/loops if out of data
}

// Mocking some other things that might be problematic
void __wrap_die(const char *s) {
    (void)s;
    exit(1);
}

char *__wrap_editorPrompt(char *prompt, void (*callback)(char *, int)) {
    (void)prompt;
    (void)callback;
    // Return a fuzzed string or NULL
    if (__wrap_readKey() % 2) {
        return strdup("fuzzed_input");
    }
    return NULL;
}

// We need to provide these if we don't link main.o or if we link it but it's not enough
// Since we link main.o with -Dmain=original_main, these should be provided by main.o
// but if there are issues, we can redefine them here.

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 1) return 0;

    fuzz_data = data;
    fuzz_size = size;
    fuzz_offset = 0;

    // Reset editor state for each iteration
    // Since E is global, we need a way to reset it. 
    // initEditor() helps but might not clear everything.
    memset(&E, 0, sizeof(E));
    initEditor();
    
    // Mock screen size
    E.screenrows = 24;
    E.screencols = 80;

    // Use the first few bytes to decide what to do
    uint8_t action = data[fuzz_offset++] % 4;

    if (action == 0) {
        // Fuzz file opening
        char temp_file[] = "/tmp/fuzz_videre_XXXXXX";
        int fd = mkstemp(temp_file);
        if (fd != -1) {
            size_t remaining = size - fuzz_offset;
            if (remaining > 0) {
                write(fd, &data[fuzz_offset], remaining);
            }
            close(fd);
            editorOpen(temp_file);
            unlink(temp_file);
        }
    } else {
        // Start with some random rows to test manipulations
        editorInsertRow(0, "Hello World", 11);
        
        // Process remaining bytes as keypresses
        while (fuzz_offset < fuzz_size) {
            editorProcessKeypress();
            
            // Limit loop to avoid infinite execution
            if (fuzz_offset > 500) break;
        }
    }

    // Cleanup E.row and other allocations
    for (int i = 0; i < E.numrows; i++) {
        free(E.row[i].chars);
        free(E.row[i].hl);
    }
    free(E.row);
    if (E.filename) free(E.filename);
    
    // Free undo/redo stacks
    while (E.undo_stack) {
        editorUndoState *next = E.undo_stack->next;
        editorFreeUndoState(E.undo_stack);
        E.undo_stack = next;
    }
    while (E.redo_stack) {
        editorUndoState *next = E.redo_stack->next;
        editorFreeUndoState(E.redo_stack);
        E.redo_stack = next;
    }

    return 0;
}

#ifdef __AFL_COMPILER
int main(void) {
    uint8_t buf[65536];
    // Use AFL persistent mode
    while (__AFL_LOOP(1000)) {
        int len = read(0, buf, sizeof(buf));
        if (len <= 0) break;
        LLVMFuzzerTestOneInput(buf, len);
    }
    return 0;
}
#else
int main(int argc, char **argv) {
    if (argc < 2) return 1;
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;
    uint8_t buf[65536];
    size_t len = fread(buf, 1, sizeof(buf), f);
    fclose(f);
    LLVMFuzzerTestOneInput(buf, len);
    return 0;
}
#endif