#include "videre.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <ctype.h>

static char *base64_encode(const unsigned char *data, size_t input_length) {
    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    size_t output_length = 4 * ((input_length + 2) / 3);
    char *encoded_data = malloc(output_length + 1);
    if (encoded_data == NULL) return NULL;

    for (size_t i = 0, j = 0; i < input_length;) {
        uint32_t octet_a = i < input_length ? data[i++] : 0;
        uint32_t octet_b = i < input_length ? data[i++] : 0;
        uint32_t octet_c = i < input_length ? data[i++] : 0;

        uint32_t triple = (octet_a << 0x10) + (octet_b << 0x08) + octet_c;

        encoded_data[j++] = table[(triple >> 3 * 6) & 0x3F];
        encoded_data[j++] = table[(triple >> 2 * 6) & 0x3F];
        encoded_data[j++] = (i > input_length + 1) ? '=' : table[(triple >> 1 * 6) & 0x3F];
        encoded_data[j++] = (i > input_length) ? '=' : table[(triple >> 0 * 6) & 0x3F];
    }
    encoded_data[output_length] = '\0';
    return encoded_data;
}

void editorSetClipboard(const char *text) {
    if (!text) return;

    // OSC 52: Native terminal clipboard support (works in Ghostty, Kitty, etc.)
    char *encoded = base64_encode((const unsigned char *)text, strlen(text));
    if (encoded) {
        // ESC ] 52 ; c ; <base64> BEL
        printf("\x1b]52;c;%s\x07", encoded);
        fflush(stdout);
        free(encoded);
    }

    // External tool fallbacks (for tmux/headless/standard terminals)
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
    E.preferredColumn = E.cx;
}

void editorIncrementNumber(int count) {
    if (E.cy >= E.numrows) return;
    erow *row = &E.row[E.cy];
    int i = E.cx;
    
    // Find number on current line
    while (i < row->size && !isdigit(row->chars[i])) {
        if (row->chars[i] == '-' && i + 1 < row->size && isdigit(row->chars[i+1])) {
            break;
        }
        i++;
    }
    
    if (i < row->size) {
        char *endptr;
        long val = strtol(&row->chars[i], &endptr, 10);
        int num_len = endptr - &row->chars[i];
        val += count;
        
        char buf[32];
        int new_len = snprintf(buf, sizeof(buf), "%ld", val);
        
        int diff = new_len - num_len;
        editorSaveUndoState();
        
        char *new_chars = malloc(row->size + diff + 1);
        memcpy(new_chars, row->chars, i);
        memcpy(new_chars + i, buf, new_len);
        memcpy(new_chars + i + new_len, endptr, row->size - (i + num_len));
        new_chars[row->size + diff] = '\0';
        
        free(row->chars);
        row->chars = new_chars;
        row->size += diff;
        E.cx = i + new_len - 1;
        E.preferredColumn = E.cx;
        editorUpdateRow(row);
        E.dirty++;
    }
}