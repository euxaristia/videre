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
    E.preferredColumn = 0;
    E.rowoff = 0;
    E.coloff = 0;
    E.numrows = 0;
    E.row_capacity = 0;
    E.row = NULL;
    E.dirty = 0;
    E.filename = NULL;
    E.git_status[0] = '\0';
    E.statusmsg[0] = 0;
    E.statusmsg_time = 0;
    E.mode = MODE_NORMAL;
    E.is_dragging = 0;
    E.paste_buffer = NULL;
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
    
    for (int i = 0; i < 26; i++) E.mark_set[i] = 0;

    E.menu_open = 0;
    E.menu_x = E.menu_y = 0;
    E.menu_selected = 0;

    getWindowSize(&E.screenrows, &E.screencols);
    if (E.screenrows < 3) E.screenrows = 1;
    else E.screenrows -= 2; 
}

int editorGetGutterWidth(void) {
    if (E.filename == NULL && E.numrows == 0) return 0;

    int max_line = E.numrows > 0 ? E.numrows : 1;
    int digits = 1;
    while (max_line >= 10) {
        digits++;
        max_line /= 10;
    }
    return digits;
}

void editorInsertChar(int c) {
    editorSaveUndoState();
    if (E.cy == E.numrows) {
        editorInsertRow(E.numrows, "", 0);
    }
    editorRowInsertChar(&E.row[E.cy], E.cx, c);
    E.cx++;
    E.preferredColumn = E.cx;
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
    E.preferredColumn = 0;
}

void editorDelChar() {
    if (E.cy == E.numrows) return;
    if (E.cx == 0 && E.cy == 0) return;

    editorSaveUndoState();
    erow *row = &E.row[E.cy];
    if (E.cx > 0) {
        editorRowDelChar(row, E.cx - 1);
        E.cx--;
        E.preferredColumn = E.cx;
    } else {
        E.cx = E.row[E.cy - 1].size;
        E.preferredColumn = E.cx;
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
                E.preferredColumn = E.cx;
            } else if (E.cy > 0) {
                E.cy--;
                E.cx = E.row[E.cy].size;
                E.preferredColumn = E.cx;
            }
            break;
        case ARROW_RIGHT:
            if (row && E.cx < row->size) {
                E.cx++;
                E.preferredColumn = E.cx;
            } else if (row && E.cx == row->size && E.mode == MODE_INSERT && E.cy < E.numrows - 1) {
                E.cy++;
                E.cx = 0;
                E.preferredColumn = E.cx;
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

    // Never allow virtual line below EOF when buffer has content.
    if (E.numrows > 0 && E.cy >= E.numrows) {
        E.cy = E.numrows - 1;
    }
    if (E.cy < 0) E.cy = 0;

    row = (E.cy >= E.numrows) ? NULL : &E.row[E.cy];
    int rowlen = row ? row->size : 0;

    int maxcol = rowlen;
    if (E.mode != MODE_INSERT && rowlen > 0) {
        maxcol = rowlen - 1;
    }

    if (key == ARROW_UP || key == ARROW_DOWN) {
        if (E.preferredColumn > maxcol) {
            E.cx = maxcol;
        } else {
            E.cx = E.preferredColumn;
        }
    } else {
        if (E.cx > maxcol) {
            E.cx = maxcol;
        }
    }
    if (E.cx < 0) E.cx = 0;
}

// Character search functions
void editorFindChar(char c, int direction) {
    E.last_search_char = c;
    E.last_search_char_found = 0;
    
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
                    E.preferredColumn = E.cx;
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
                    E.preferredColumn = E.cx;
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
                    E.preferredColumn = E.cx;
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
                    E.preferredColumn = E.cx;
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
            E.preferredColumn = E.cx;
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
        E.preferredColumn = 1000000;
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
            E.preferredColumn = E.cx;
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
    E.preferredColumn = 0;
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
            E.preferredColumn = E.cx;
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

// Line motions
void editorMoveToLineStart() {
    E.cx = 0;
    E.preferredColumn = 0;
}

void editorMoveToFirstNonWhitespace() {
    if (E.cy >= E.numrows) return;
    erow *row = &E.row[E.cy];
    int col = 0;
    while (col < row->size && (row->chars[col] == ' ' || row->chars[col] == '\t')) {
        col++;
    }
    E.cx = col;
    E.preferredColumn = col;
}

void editorMoveToLineEnd() {
    if (E.cy >= E.numrows) return;
    E.cx = E.row[E.cy].size;
    E.preferredColumn = 1000000; // Large value to stay at EOL
}

void editorMoveToFileStart() {
    E.cy = 0;
    E.cx = 0;
    E.preferredColumn = 0;
}

void editorMoveToFileEnd() {
    if (E.numrows == 0) return;
    E.cy = E.numrows - 1;
    E.cx = E.row[E.cy].size;
    E.preferredColumn = 1000000;
}

void editorGoToLine(int line_num) {
    if (line_num < 1) line_num = 1;
    if (line_num > E.numrows) line_num = E.numrows;
    E.cy = line_num - 1;
    E.cx = 0;
    E.preferredColumn = 0;
}

// Check if a row is blank (empty or only whitespace)
static int is_blank_row(int row_idx) {
    if (row_idx < 0 || row_idx >= E.numrows) return 1;
    erow *row = &E.row[row_idx];
    if (row->size == 0) return 1;
    for (int i = 0; i < row->size; i++) {
        if (row->chars[i] != ' ' && row->chars[i] != '\t') {
            return 0;
        }
    }
    return 1;
}

// Move to previous paragraph ({ command)
void editorMoveToPreviousParagraph() {
    if (E.numrows == 0) return;
    
    int row = E.cy;
    
    // If we're on a non-blank line, first move to the blank line before this paragraph
    if (!is_blank_row(row)) {
        while (row > 0 && !is_blank_row(row - 1)) {
            row--;
        }
    }
    
    // Now skip blank lines to find the start of the previous paragraph
    while (row > 0 && is_blank_row(row - 1)) {
        row--;
    }
    
    // Move to the start of the previous paragraph
    while (row > 0 && !is_blank_row(row - 1)) {
        row--;
    }
    
    E.cy = row;
    E.cx = 0;
    E.preferredColumn = 0;
}

// Move to next paragraph (} command)
void editorMoveToNextParagraph() {
    if (E.numrows == 0) return;
    
    int row = E.cy;
    
    // If we're on a non-blank line, first move to the blank line after this paragraph
    if (!is_blank_row(row)) {
        while (row < E.numrows - 1 && !is_blank_row(row + 1)) {
            row++;
        }
    }
    
    // Now skip blank lines to find the start of the next paragraph
    while (row < E.numrows - 1 && is_blank_row(row + 1)) {
        row++;
    }
    
    // Move to the start of the next paragraph
    if (row < E.numrows - 1) {
        row++;
    }
    
    E.cy = row;
    E.cx = 0;
    E.preferredColumn = 0;
}

// Helper function to change case of a character range
static void change_case_range(int start_y, int start_x, int end_y, int end_x, int to_upper) {
    for (int row = start_y; row <= end_y; row++) {
        if (row < 0 || row >= E.numrows) continue;
        erow *r = &E.row[row];
        int col_start = (row == start_y) ? start_x : 0;
        int col_end = (row == end_y) ? end_x : r->size;
        
        for (int col = col_start; col < col_end && col < r->size; col++) {
            if (to_upper) {
                r->chars[col] = toupper(r->chars[col]);
            } else {
                r->chars[col] = tolower(r->chars[col]);
            }
        }
    }
}

// Change case of text (gu = lowercase, gU = uppercase)
void editorChangeCase(int to_upper) {
    if (E.mode != MODE_VISUAL && E.mode != MODE_VISUAL_LINE) return;
    
    int start_y = E.sel_sy;
    int start_x = E.sel_sx;
    int end_y = E.cy;
    int end_x = E.cx;
    
    // Normalize range
    if (start_y > end_y || (start_y == end_y && start_x > end_x)) {
        int tmp = start_y; start_y = end_y; end_y = tmp;
        tmp = start_x; start_x = end_x; end_x = tmp;
    }
    
    editorSaveUndoState();
    change_case_range(start_y, start_x, end_y, end_x, to_upper);
    
    E.mode = MODE_NORMAL;
    E.sel_sx = E.sel_sy = -1;
    E.preferredColumn = E.cx;
}

// Indent/Unindent lines (> and < operators)
void editorIndent(int indent) {
    if (E.mode != MODE_VISUAL && E.mode != MODE_VISUAL_LINE) return;
    
    int start_y = E.sel_sy;
    int end_y = E.cy;
    
    // Normalize range
    if (start_y > end_y) {
        int tmp = start_y; start_y = end_y; end_y = tmp;
    }
    
    editorSaveUndoState();
    
    for (int row = start_y; row <= end_y; row++) {
        if (row < 0 || row >= E.numrows) continue;
        erow *r = &E.row[row];
        
        if (indent) {
            // Add 4 spaces at beginning
            char *new_chars = malloc(r->size + 5);
            if (new_chars) {
                memcpy(new_chars, "    ", 4);
                memcpy(new_chars + 4, r->chars, r->size);
                new_chars[r->size + 4] = '\0';
                free(r->chars);
                r->chars = new_chars;
                r->size += 4;
            }
        } else {
            // Remove up to 4 spaces from beginning
            int spaces_to_remove = 0;
            while (spaces_to_remove < 4 && spaces_to_remove < r->size && 
                   r->chars[spaces_to_remove] == ' ') {
                spaces_to_remove++;
            }
            if (spaces_to_remove > 0) {
                memmove(r->chars, r->chars + spaces_to_remove, r->size - spaces_to_remove + 1);
                r->size -= spaces_to_remove;
            }
        }
    }
    
    E.mode = MODE_NORMAL;
    E.sel_sx = E.sel_sy = -1;
    E.preferredColumn = E.cx;
}

void editorSetMark(int mark) {
    if (mark < 'a' || mark > 'z') return;
    int idx = mark - 'a';
    E.mark_x[idx] = E.cx;
    E.mark_y[idx] = E.cy;
    E.mark_set[idx] = 1;
    editorSetStatusMessage("Mark '%c' set", mark);
}

void editorGoToMark(int mark) {
    if (mark < 'a' || mark > 'z') return;
    int idx = mark - 'a';
    if (!E.mark_set[idx]) {
        editorSetStatusMessage("Mark '%c' not set", mark);
        return;
    }
    E.cy = E.mark_y[idx];
    if (E.cy >= E.numrows) E.cy = E.numrows - 1;
    if (E.cy < 0) E.cy = 0;
    
    E.cx = E.mark_x[idx];
    if (E.cx > E.row[E.cy].size) E.cx = E.row[E.cy].size;
    
    E.preferredColumn = E.cx;
    editorSetStatusMessage("Jumped to mark '%c'", mark);
}
