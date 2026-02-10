#include "videre.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

void editorUpdateRow(erow *row) {
    int filerow = row->idx;
    int was_open = row->hl_open_comment;
    
    editorUpdateSyntax(row);
    
    // Propagate multi-line comment state changes
    if (row->hl_open_comment != was_open) {
        for (int i = filerow + 1; i < E.numrows; i++) {
            int prev_was_open = E.row[i].hl_open_comment;
            editorUpdateSyntax(&E.row[i]);
            if (E.row[i].hl_open_comment == prev_was_open) break;
        }
    }
}

void editorInsertRow(int at, char *s, size_t len) {
    if (at < 0 || at > E.numrows) return;

    if (E.numrows >= E.row_capacity) {
        E.row_capacity = E.row_capacity == 0 ? 128 : E.row_capacity * 2;
        erow *new_rows = realloc(E.row, sizeof(erow) * E.row_capacity);
        if (!new_rows) die("realloc");
        E.row = new_rows;
    }
    
    if (at < E.numrows) {
        memmove(&E.row[at + 1], &E.row[at], sizeof(erow) * (E.numrows - at));
        for (int j = at + 1; j <= E.numrows; j++) E.row[j].idx++;
    }

    E.row[at].idx = at;
    E.row[at].size = len;
    E.row[at].chars = malloc(len + 1);
    if (!E.row[at].chars) die("malloc");
    memcpy(E.row[at].chars, s, len);
    E.row[at].chars[len] = '\0';
    
    E.row[at].hl = NULL;
    E.row[at].hl_open_comment = 0;
    editorUpdateSyntax(&E.row[at]);

    E.numrows++;
    E.dirty++;
}

void editorFreeRow(erow *row) {
    free(row->chars);
    free(row->hl);
}

void editorDelRow(int at) {
    if (at < 0 || at >= E.numrows) return;
    editorFreeRow(&E.row[at]);
    memmove(&E.row[at], &E.row[at + 1], sizeof(erow) * (E.numrows - at - 1));
    for (int j = at; j < E.numrows - 1; j++) E.row[j].idx--;
    E.numrows--;
    E.dirty++;
}

void editorRowInsertChar(erow *row, int at, int c) {
    if (at < 0 || at > row->size) at = row->size;
    row->chars = realloc(row->chars, row->size + 2);
    if (!row->chars) die("realloc");
    memmove(&row->chars[at + 1], &row->chars[at], row->size - at + 1);
    row->size++;
    row->chars[at] = c;
    editorUpdateRow(row);
    E.dirty++;
}

void editorRowAppendString(erow *row, char *s, size_t len) {
    row->chars = realloc(row->chars, row->size + len + 1);
    if (!row->chars) die("realloc");
    memcpy(&row->chars[row->size], s, len);
    row->size += len;
    row->chars[row->size] = '\0';
    editorUpdateRow(row);
    E.dirty++;
}

void editorRowDelChar(erow *row, int at) {
    if (at < 0 || at >= row->size) return;
    memmove(&row->chars[at], &row->chars[at + 1], row->size - at);
    row->size--;
    editorUpdateRow(row);
    E.dirty++;
}

void editorDeleteRange(int sx, int sy, int ex, int ey) {
    if (sy > ey || (sy == ey && sx > ex)) {
        int tx = sx; sx = ex; ex = tx;
        int ty = sy; sy = ey; ey = ty;
    }
    
    editorSaveUndoState();

    if (sy == ey) {
        int len = ex - sx + 1;
        erow *row = &E.row[sy];
        if (sx + len <= row->size) {
            memmove(&row->chars[sx], &row->chars[sx + len], row->size - (sx + len));
            row->size -= len;
            row->chars[row->size] = '\0';
            editorUpdateRow(row);
        }
    } else {
        erow *first = &E.row[sy];
        erow *last = &E.row[ey];
        
        int new_size = sx + (last->size - ex - 1);
        char *new_chars = malloc(new_size + 1);
        if (!new_chars) die("malloc");
        memcpy(new_chars, first->chars, sx);
        if (last->size > ex + 1) {
            memcpy(&new_chars[sx], &last->chars[ex + 1], last->size - ex - 1);
        }
        new_chars[new_size] = '\0';
        
        free(first->chars);
        first->chars = new_chars;
        first->size = new_size;
        editorUpdateRow(first);
        
        for (int i = 0; i < (ey - sy); i++) {
            editorDelRow(sy + 1);
        }
    }
    
    E.cx = sx;
    E.cy = sy;
    E.dirty++;
}

int is_word_char(char c) {
    return isalnum(c) || c == '_';
}

void editorSelectWord() {
    if (E.cy >= E.numrows) return;
    erow *row = &E.row[E.cy];
    if (row->size == 0) return;
    
    int sx = E.cx;
    while (sx > 0 && is_word_char(row->chars[sx - 1])) sx--;
    
    int ex = E.cx;
    while (ex < row->size - 1 && is_word_char(row->chars[ex + 1])) ex++;
    
    E.mode = MODE_VISUAL;
    E.sel_sx = sx;
    E.sel_sy = E.cy;
    E.cx = ex;
}
