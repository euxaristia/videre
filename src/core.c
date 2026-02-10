#include <ctype.h>
#include "videre.h"
#include "terminal.h"
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

void initEditor() {
    E.cx = 0;
    E.cy = 0;
    E.rowoff = 0;
    E.coloff = 0;
    E.numrows = 0;
    E.row_capacity = 0;
    E.row = NULL;
    E.dirty = 0;
    E.filename = NULL;
    E.statusmsg[0] = 0;
    E.statusmsg_time = 0;
    E.mode = MODE_NORMAL;
    E.is_dragging = 0;
    E.sel_sx = E.sel_sy = -1;
    
    for (int i = 0; i < 256; i++) {
        E.registers[i].chars = NULL;
        E.registers[i].size = 0;
        E.registers[i].is_line = 0;
    }
    E.undo_stack = NULL;
    E.redo_stack = NULL;
    E.search_pattern = NULL;
    E.last_search_char = '\0';
    E.last_search_char_found = 0;

    getWindowSize(&E.screenrows, &E.screencols);
    if (E.screenrows < 3) E.screenrows = 1;
    else E.screenrows -= 2; 
}

void editorInsertChar(int c) {
    editorSaveUndoState();
    if (E.cy == E.numrows) {
        editorInsertRow(E.numrows, "", 0);
    }
    editorRowInsertChar(&E.row[E.cy], E.cx, c);
    E.cx++;
}

void editorInsertNewline() {
    editorSaveUndoState();
    if (E.cx == 0) {
        editorInsertRow(E.cy, "", 0);
    } else {
        erow *row = &E.row[E.cy];
        editorInsertRow(E.cy + 1, &row->chars[E.cx], row->size - E.cx);
        row = &E.row[E.cy];
        row->size = E.cx;
        row->chars[row->size] = 0;
        editorUpdateRow(row);
    }
    E.cy++;
    E.cx = 0;
}

void editorDelChar() {
    if (E.cy == E.numrows) return;
    if (E.cx == 0 && E.cy == 0) return;

    editorSaveUndoState();
    erow *row = &E.row[E.cy];
    if (E.cx > 0) {
        editorRowDelChar(row, E.cx - 1);
        E.cx--;
    } else {
        E.cx = E.row[E.cy - 1].size;
        row = &E.row[E.cy];
        E.row[E.cy - 1].chars = realloc(E.row[E.cy - 1].chars, E.row[E.cy - 1].size + row->size + 1);
        memcpy(&E.row[E.cy - 1].chars[E.row[E.cy - 1].size], row->chars, row->size);
        E.row[E.cy - 1].size += row->size;
        E.row[E.cy - 1].chars[E.row[E.cy - 1].size] = 0;
        editorUpdateRow(&E.row[E.cy - 1]);
        
        editorDelRow(E.cy);
        E.cy--;
    }
}

void editorScroll() {
    if (E.cy < E.rowoff) {
        E.rowoff = E.cy;
    }
    if (E.cy >= E.rowoff + E.screenrows) {
        E.rowoff = E.cy - E.screenrows + 1;
    }
    if (E.cx < E.coloff) {
        E.coloff = E.cx;
    }
    if (E.cx >= E.coloff + E.screencols) {
        E.coloff = E.cx - E.screencols + 1;
    }
}

void editorMoveCursor(int key) {
    erow *row = (E.cy >= E.numrows) ? NULL : &E.row[E.cy];

    switch (key) {
        case ARROW_LEFT:
            if (E.cx != 0) {
                E.cx--;
            } else if (E.cy > 0) {
                E.cy--;
                E.cx = E.row[E.cy].size;
            }
            break;
        case ARROW_RIGHT:
            if (row && E.cx < row->size) {
                E.cx++;
            } else if (row && E.cx == row->size) {
                E.cy++;
                E.cx = 0;
            }
            break;
        case ARROW_UP:
            if (E.cy != 0) {
                E.cy--;
            }
            break;
        case ARROW_DOWN:
            if (E.cy < E.numrows - 1) {
                E.cy++;
            }
            break;
    }

    row = (E.cy >= E.numrows) ? NULL : &E.row[E.cy];
    int rowlen = row ? row->size : 0;
    if (E.cx > rowlen) {
        E.cx = rowlen;
    }
}

// Character search functions
void editorFindChar(char c, int direction) {
    E.last_search_char = c;
    E.last_search_char_found = 0;
    
    if (E.numrows == 0) return;
    
    erow *row = &E.row[E.cy];
    int start_col = E.cx + (direction > 0 ? 1 : -1);
    
    // Search forward
    if (direction > 0) {
        for (int line = E.cy; line < E.numrows; line++) {
            erow *current_row = &E.row[line];
            int start = (line == E.cy) ? start_col : 0;
            
            for (int col = start; col < current_row->size; col++) {
                if (current_row->chars[col] == c) {
                    E.cy = line;
                    E.cx = col;
                    E.last_search_char_found = 1;
                    return;
                }
            }
        }
    }
    // Search backward
    else {
        for (int line = E.cy; line >= 0; line--) {
            erow *current_row = &E.row[line];
            int end = (line == E.cy) ? start_col : current_row->size - 1;
            
            for (int col = end; col >= 0; col--) {
                if (current_row->chars[col] == c) {
                    E.cy = line;
                    E.cx = col;
                    E.last_search_char_found = 1;
                    return;
                }
            }
        }
    }
}

void editorFindCharTill(char c, int direction) {
    E.last_search_char = c;
    E.last_search_char_found = 0;
    
    if (E.numrows == 0) return;
    
    erow *row = &E.row[E.cy];
    int start_col = E.cx + (direction > 0 ? 1 : -1);
    
    // Search forward
    if (direction > 0) {
        for (int line = E.cy; line < E.numrows; line++) {
            erow *current_row = &E.row[line];
            int start = (line == E.cy) ? start_col : 0;
            
            for (int col = start; col < current_row->size; col++) {
                if (current_row->chars[col] == c) {
                    E.cy = line;
                    E.cx = col - 1; // Position before the character
                    if (E.cx < 0) E.cx = 0;
                    E.last_search_char_found = 1;
                    return;
                }
            }
        }
    }
    // Search backward
    else {
        for (int line = E.cy; line >= 0; line--) {
            erow *current_row = &E.row[line];
            int end = (line == E.cy) ? start_col : current_row->size - 1;
            
            for (int col = end; col >= 0; col--) {
                if (current_row->chars[col] == c) {
                    E.cy = line;
                    E.cx = col + 1; // Position after the character
                    if (E.cx >= current_row->size) E.cx = current_row->size - 1;
                    E.last_search_char_found = 1;
                    return;
                }
            }
        }
    }
}

void editorRepeatCharSearch() {
    if (E.last_search_char == '\0') return;
    
    // Repeat the last character search in the same direction
    // For simplicity, we'll just call editorFindChar again
    // In a full implementation, we'd track the last search direction
    editorFindChar(E.last_search_char, 1);
}

