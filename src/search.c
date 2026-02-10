#include "videre.h"
#include <stdlib.h>
#include <string.h>

void editorFindCallback(char *query, int key) {
    static int last_match = -1;
    static int direction = 1;

    if (key == '\r' || key == '\x1b') {
        last_match = -1;
        direction = 1;
        E.search_pattern = NULL;
        return;
    } else if (key == ARROW_RIGHT || key == ARROW_DOWN) {
        direction = 1;
    } else if (key == ARROW_LEFT || key == ARROW_UP) {
        direction = -1;
    } else {
        last_match = -1;
        direction = 1;
    }

    if (last_match == -1) direction = 1;
    int current = last_match;
    int i;
    for (i = 0; i < E.numrows; i++) {
        current += direction;
        if (current == -1) current = E.numrows - 1;
        else if (current == E.numrows) current = 0;

        erow *row = &E.row[current];
        char *match = strstr(row->chars, query);
        if (match) {
            last_match = current;
            E.cy = current;
            E.cx = match - row->chars;
            E.rowoff = E.numrows;
            break;
        }
    }

    if (query && strlen(query) > 0) {
        if (E.search_pattern) free(E.search_pattern);
        E.search_pattern = strdup(query);
        editorUpdateSearchHighlight();
    }
}

void editorFind() {
    int saved_cx = E.cx;
    int saved_cy = E.cy;
    int saved_coloff = E.coloff;
    int saved_rowoff = E.rowoff;

    char *query = editorPrompt("/%s", editorFindCallback);

    if (query) {
        free(query);
    } else {
        E.cx = saved_cx;
        E.cy = saved_cy;
        E.coloff = saved_coloff;
        E.rowoff = saved_rowoff;
    }
}

void editorFindNext(int direction) {
    if (E.search_pattern == NULL || strlen(E.search_pattern) == 0) return;
    
    int current_row = E.cy;
    int current_col = E.cx + (direction > 0 ? 1 : -1);
    
    // Search from current position
    for (int i = 0; i < E.numrows; i++) {
        current_row += direction;
        if (current_row < 0) current_row = E.numrows - 1;
        if (current_row >= E.numrows) current_row = 0;
        
        erow *row = &E.row[current_row];
        char *match = NULL;
        
        if (direction > 0) {
            // Search forward
            if (current_row == E.cy) {
                // Same row, search from current position
                if (current_col < row->size) {
                    match = strstr(&row->chars[current_col], E.search_pattern);
                }
            } else {
                // Different row, search from beginning
                match = strstr(row->chars, E.search_pattern);
            }
        } else {
            // Search backward - need to search manually
            int search_len = strlen(E.search_pattern);
            int start = (current_row == E.cy) ? current_col : row->size - 1;
            
            for (int col = start; col >= 0; col--) {
                if (col + search_len <= row->size && 
                    strncmp(&row->chars[col], E.search_pattern, search_len) == 0) {
                    match = &row->chars[col];
                    break;
                }
            }
        }
        
        if (match) {
            E.cy = current_row;
            E.cx = match - row->chars;
            editorUpdateSearchHighlight();
            return;
        }
    }
}
