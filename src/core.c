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
        row->chars[row->size] = '\0';
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
        editorRowAppendString(&E.row[E.cy - 1], row->chars, row->size);
        editorDelRow(E.cy);
        E.cy--;
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
    
    if (E.numrows == 0) return;
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
    int start_col = E.cx + (direction > 0 ? 1 : -1);
    
    // Search forward (t = till, stop before)
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

// Word motion helpers
static int is_word_char(char c) {
    return isalnum(c) || c == '_';
}

static int is_blank(char c) {
    return c == ' ' || c == '\t';
}

// Move forward to start of next word (w command)
void editorMoveWordForward(int big_word) {
    if (E.numrows == 0) return;
    
    int row = E.cy;
    int col = E.cx;
    
    while (row < E.numrows) {
        erow *current_row = &E.row[row];
        
        // Skip current word if we're on one
        if (col < current_row->size) {
            if (big_word) {
                // BIG WORD: skip non-whitespace
                while (col < current_row->size && !is_blank(current_row->chars[col])) {
                    col++;
                }
            } else {
                // word: skip word characters
                if (is_word_char(current_row->chars[col])) {
                    while (col < current_row->size && is_word_char(current_row->chars[col])) {
                        col++;
                    }
                } else {
                    // skip non-word, non-whitespace characters
                    while (col < current_row->size && !is_word_char(current_row->chars[col]) && !is_blank(current_row->chars[col])) {
                        col++;
                    }
                }
            }
        }
        
        // Skip whitespace
        while (col < current_row->size && is_blank(current_row->chars[col])) {
            col++;
        }
        
        // If we found a non-whitespace character, we're at the start of next word
        if (col < current_row->size) {
            E.cy = row;
            E.cx = col;
            return;
        }
        
        // Move to next line
        row++;
        col = 0;
    }
    
    // If we reached the end, go to end of last line
    if (E.numrows > 0) {
        E.cy = E.numrows - 1;
        E.cx = E.row[E.cy].size;
    }
}

// Move backward to start of previous word (b command)
void editorMoveWordBackward(int big_word) {
    if (E.numrows == 0) return;
    
    int row = E.cy;
    int col = E.cx - 1;  // Start from character before cursor
    
    while (row >= 0) {
        erow *current_row = &E.row[row];
        
        // Skip whitespace going backward
        while (col >= 0 && is_blank(current_row->chars[col])) {
            col--;
        }
        
        // If we found a non-whitespace character
        if (col >= 0) {
            if (big_word) {
                // BIG WORD: skip non-whitespace backward
                while (col >= 0 && !is_blank(current_row->chars[col])) {
                    col--;
                }
            } else {
                // word: skip word characters backward
                if (is_word_char(current_row->chars[col])) {
                    while (col >= 0 && is_word_char(current_row->chars[col])) {
                        col--;
                    }
                } else {
                    // skip non-word, non-whitespace characters backward
                    while (col >= 0 && !is_word_char(current_row->chars[col]) && !is_blank(current_row->chars[col])) {
                        col--;
                    }
                }
            }
            
            E.cy = row;
            E.cx = col + 1;
            return;
        }
        
        // Move to previous line
        row--;
        if (row >= 0) {
            col = E.row[row].size - 1;
        }
    }
    
    // If we reached the beginning
    E.cy = 0;
    E.cx = 0;
}

// Move forward to end of word (e command)
void editorMoveWordEnd(int big_word) {
    if (E.numrows == 0) return;
    
    int row = E.cy;
    int col = E.cx + 1;  // Start from character after cursor
    
    while (row < E.numrows) {
        erow *current_row = &E.row[row];
        
        // Skip whitespace
        while (col < current_row->size && is_blank(current_row->chars[col])) {
            col++;
        }
        
        // If we found a non-whitespace character
        if (col < current_row->size) {
            if (big_word) {
                // BIG WORD: skip to end of non-whitespace
                while (col < current_row->size - 1 && !is_blank(current_row->chars[col + 1])) {
                    col++;
                }
            } else {
                // word: skip to end of word characters
                if (is_word_char(current_row->chars[col])) {
                    while (col < current_row->size - 1 && is_word_char(current_row->chars[col + 1])) {
                        col++;
                    }
                } else {
                    // skip to end of non-word, non-whitespace characters
                    while (col < current_row->size - 1 && !is_word_char(current_row->chars[col + 1]) && !is_blank(current_row->chars[col + 1])) {
                        col++;
                    }
                }
            }
            
            E.cy = row;
            E.cx = col;
            return;
        }
        
        // Move to next line
        row++;
        col = 0;
    }
}

// Bracket matching - find matching bracket for () [] {}
void editorMatchBracket() {
    if (E.numrows == 0) return;
    if (E.cy >= E.numrows) return;
    
    erow *row = &E.row[E.cy];
    if (E.cx >= row->size) return;
    
    char current = row->chars[E.cx];
    char target = 0;
    int direction = 0;
    int depth = 1;
    
    // Determine what we're looking for
    switch (current) {
        case '(': target = ')'; direction = 1; break;
        case ')': target = '('; direction = -1; break;
        case '[': target = ']'; direction = 1; break;
        case ']': target = '['; direction = -1; break;
        case '{': target = '}'; direction = 1; break;
        case '}': target = '{'; direction = -1; break;
        default: return;  // Not on a bracket
    }
    
    int row_idx = E.cy;
    int col_idx = E.cx + direction;
    
    while (row_idx >= 0 && row_idx < E.numrows) {
        row = &E.row[row_idx];
        
        while (col_idx >= 0 && col_idx < row->size) {
            char c = row->chars[col_idx];
            
            if (c == current) {
                depth++;
            } else if (c == target) {
                depth--;
                if (depth == 0) {
                    E.cy = row_idx;
                    E.cx = col_idx;
                    return;
                }
            }
            
            col_idx += direction;
        }
        
        // Move to next/previous line
        row_idx += direction;
        if (direction > 0) {
            col_idx = 0;
        } else {
            if (row_idx >= 0) {
                col_idx = E.row[row_idx].size - 1;
            }
        }
    }
}
