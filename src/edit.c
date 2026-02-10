#include "videre.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

void editorSetClipboard(const char *text) {
    if (!text) return;
    FILE *pipe = popen("wl-copy", "w");
    if (!pipe) pipe = popen("xclip -selection clipboard", "w");
    
    if (pipe) {
        fwrite(text, 1, strlen(text), pipe);
        pclose(pipe);
    }
}

char *editorGetClipboard() {
    FILE *pipe = popen("wl-paste -n", "r");
    if (!pipe) pipe = popen("xclip -selection clipboard -o", "r");
    
    if (!pipe) return NULL;
    
    size_t size = 1024;
    char *buf = malloc(size);
    size_t len = 0;
    char chunk[1024];
    
    while (fgets(chunk, sizeof(chunk), pipe)) {
        size_t chunk_len = strlen(chunk);
        if (len + chunk_len + 1 > size) {
            size *= 2;
            buf = realloc(buf, size);
        }
        memcpy(buf + len, chunk, chunk_len);
        len += chunk_len;
    }
    buf[len] = '\0';
    pclose(pipe);
    
    if (len == 0) {
        free(buf);
        return NULL;
    }
    return buf;
}

void editorYank(int sx, int sy, int ex, int ey, int is_line) {
    if (sy > ey || (sy == ey && sx > ex)) {
        int tx = sx; sx = ex; ex = tx;
        int ty = sy; sy = ey; ey = ty;
    }

    editorRegister *reg = &E.registers['\"']; // Unnamed register
    free(reg->chars);
    reg->is_line = is_line;

    if (is_line) {
        int total_size = 0;
        for (int i = sy; i <= ey; i++) total_size += E.row[i].size + 1;
        reg->chars = malloc(total_size + 1);
        char *p = reg->chars;
        for (int i = sy; i <= ey; i++) {
            memcpy(p, E.row[i].chars, E.row[i].size);
            p += E.row[i].size;
            *p++ = '\n';
        }
        *p = '\0';
        reg->size = total_size;
    } else {
        if (sy == ey) {
            reg->size = ex - sx + 1;
            reg->chars = malloc(reg->size + 1);
            memcpy(reg->chars, &E.row[sy].chars[sx], reg->size);
            reg->chars[reg->size] = '\0';
        } else {
            int total_size = E.row[sy].size - sx + 1;
            for (int i = sy + 1; i < ey; i++) total_size += E.row[i].size + 1;
            total_size += ex + 1;
            reg->chars = malloc(total_size + 1);
            char *p = reg->chars;
            
            memcpy(p, &E.row[sy].chars[sx], E.row[sy].size - sx);
            p += E.row[sy].size - sx;
            *p++ = '\n';
            
            for (int i = sy + 1; i < ey; i++) {
                memcpy(p, E.row[i].chars, E.row[i].size);
                p += E.row[i].size;
                *p++ = '\n';
            }
            
            memcpy(p, E.row[ey].chars, ex + 1);
            p += ex + 1;
            *p = '\0';
            reg->size = total_size;
        }
    }
    
    // Sync with system clipboard
    editorSetClipboard(reg->chars);
}

void editorPaste() {
    // Try to get from system clipboard first
    char *clip = editorGetClipboard();
    if (clip) {
        editorRegister *reg = &E.registers['\"'];
        free(reg->chars);
        reg->chars = clip;
        reg->size = strlen(clip);
        reg->is_line = (strchr(clip, '\n') != NULL);
    }

    editorRegister *reg = &E.registers['\"'];
    if (!reg->chars) return;
    
    editorSaveUndoState();

    if (reg->is_line) {
        char *p = reg->chars;
        int line_at = E.cy + 1;
        while (p && *p) {
            char *next = strchr(p, '\n');
            int len = next ? (next - p) : (int)strlen(p);
            editorInsertRow(line_at++, p, len);
            if (next) p = next + 1;
            else break;
        }
    } else {
        for (int i = 0; reg->chars[i]; i++) {
            if (reg->chars[i] == '\n') editorInsertNewline();
            else editorInsertChar(reg->chars[i]);
        }
    }
}

void editorSelectAll() {
    E.mode = MODE_VISUAL;
    E.sel_sy = 0;
    E.sel_sx = 0;
    E.cy = E.numrows - 1;
    if (E.numrows > 0) E.cx = E.row[E.cy].size;
    else E.cx = 0;
}