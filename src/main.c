#include <ctype.h>
#include "videre.h"
#include "terminal.h"
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>
#include <stdint.h>
#include <locale.h>

// --- Status Message ---

void editorSetStatusMessage(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    
    // Basic format string validation - prevent format string attacks
    if (fmt) {
        for (const char *p = fmt; *p; p++) {
            if (*p == '%' && *(p + 1) != '\0' && 
                !strchr("diouxXfFeEgGcsaAn", *(p + 1))) {
                // Invalid format specifier, abort
                va_end(ap);
                snprintf(E.statusmsg, sizeof(E.statusmsg), "Invalid format");
                E.statusmsg_time = time(NULL);
                return;
            }
        }
    }
    
    int len = vsnprintf(E.statusmsg, sizeof(E.statusmsg), fmt, ap);
    va_end(ap);
    
    // Ensure null termination
    if (len >= (int)sizeof(E.statusmsg)) {
        E.statusmsg[sizeof(E.statusmsg) - 1] = '\0';
    }
    E.statusmsg_time = time(NULL);
}

// --- Prompt ---

char *editorPrompt(char *prompt, void (*callback)(char *, int)) {
    size_t bufsize = 128;
    char *buf = malloc(bufsize);
    if (!buf) return NULL;
    size_t buflen = 0;
    buf[0] = '\0';

    while (1) {
        editorSetStatusMessage(prompt, buf);
        editorRefreshScreen();

        int c = readKey();
        if (c == DEL_KEY || c == BACKSPACE || c == 127 || c == 8) {
            if (buflen != 0) buf[--buflen] = '\0';
        } else if (c == '\x1b') {
            editorSetStatusMessage("");
            if (callback) callback(buf, c);
            free(buf);
            return NULL;
        } else if (c == '\r') {
            if (buflen != 0) {
                editorSetStatusMessage("");
                if (callback) callback(buf, c);
                return buf;
            }
        } else if (!iscntrl(c) && c < 128) {
            if (buflen == bufsize - 1) {
                bufsize *= 2;
                char *newbuf = realloc(buf, bufsize);
                if (!newbuf) {
                    free(buf);
                    return NULL;
                }
                buf = newbuf;
            }
            buf[buflen++] = c;
            buf[buflen] = '\0';
        }

        if (callback) callback(buf, c);
    }
}

// --- Rendering ---

static int editorUtf8CharLen(unsigned char c) {
    if ((c & 0x80) == 0) return 1;
    if ((c & 0xE0) == 0xC0) return 2;
    if ((c & 0xF0) == 0xE0) return 3;
    if ((c & 0xF8) == 0xF0) return 4;
    return 1;
}

static int editorDecodeUtf8(const char *s, int avail, uint32_t *codepoint) {
    if (avail <= 0) return 0;
    const unsigned char c0 = (unsigned char)s[0];
    int len = editorUtf8CharLen(c0);
    if (len > avail) len = 1;

    if (len == 1) {
        *codepoint = c0;
        return 1;
    }

    uint32_t cp = c0 & ((1 << (8 - len - 1)) - 1);
    for (int i = 1; i < len; i++) {
        unsigned char cx = (unsigned char)s[i];
        if ((cx & 0xC0) != 0x80) {
            *codepoint = c0;
            return 1;
        }
        cp = (cp << 6) | (cx & 0x3F);
    }

    *codepoint = cp;
    return len;
}

static int editorCodepointWidth(uint32_t cp) {
    // Control chars and combining marks are zero-width for cursor math.
    if (cp < 0x20 || (cp >= 0x7F && cp < 0xA0)) return 0;
    if ((cp >= 0x0300 && cp <= 0x036F) || (cp >= 0x1AB0 && cp <= 0x1AFF) ||
        (cp >= 0x1DC0 && cp <= 0x1DFF) || (cp >= 0x20D0 && cp <= 0x20FF) ||
        (cp >= 0xFE20 && cp <= 0xFE2F) || cp == 0x200D ||
        (cp >= 0xFE00 && cp <= 0xFE0F)) {
        return 0;
    }

    // Common wide ranges (CJK + emoji/pictographs).
    if ((cp >= 0x1100 && cp <= 0x115F) || (cp >= 0x2329 && cp <= 0x232A) ||
        (cp >= 0x2E80 && cp <= 0xA4CF) || (cp >= 0xAC00 && cp <= 0xD7A3) ||
        (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0xFE10 && cp <= 0xFE19) ||
        (cp >= 0xFE30 && cp <= 0xFE6F) || (cp >= 0xFF00 && cp <= 0xFF60) ||
        (cp >= 0xFFE0 && cp <= 0xFFE6) || (cp >= 0x1F300 && cp <= 0x1FAFF) ||
        (cp >= 0x2600 && cp <= 0x27BF)) {
        return 2;
    }

    return 1;
}

static int editorDisplayWidthBytes(const char *s, int len) {
    int width = 0;
    int i = 0;
    while (i < len) {
        uint32_t cp = 0;
        int clen = editorDecodeUtf8(&s[i], len - i, &cp);
        int cw = editorCodepointWidth(cp);
        if (cw < 0) cw = 1;
        width += cw;
        i += clen;
    }
    return width;
}

static int editorSnapToUtf8Boundary(const char *s, int size, int idx) {
    if (idx <= 0) return 0;
    if (idx >= size) return size;
    while (idx > 0 && (((unsigned char)s[idx] & 0xC0) == 0x80)) {
        idx--;
    }
    return idx;
}

static int editorByteIndexFromDisplayCol(const char *s, int len, int target_col) {
    if (target_col <= 0) return 0;
    int i = 0;
    int col = 0;
    while (i < len) {
        uint32_t cp = 0;
        int clen = editorDecodeUtf8(&s[i], len - i, &cp);
        int cw = editorCodepointWidth(cp);
        if (cw < 0) cw = 1;
        if (col + cw > target_col) break;
        col += cw;
        i += clen;
    }
    return i;
}

int editorRowIsSelected(int filerow, int x) {
    if (E.mode != MODE_VISUAL && E.mode != MODE_VISUAL_LINE) return 0;
    
    int sy = E.sel_sy, ey = E.cy;
    int sx = E.sel_sx, ex = E.cx;
    
    if (sy > ey) {
        int tmp = sy; sy = ey; ey = tmp;
        tmp = sx; sx = ex; ex = tmp;
    } else if (sy == ey && sx > ex) {
        int tmp = sx; sx = ex; ex = tmp;
    }
    
    if (E.mode == MODE_VISUAL_LINE) {
        return (filerow >= sy && filerow <= ey);
    }
    
    if (filerow < sy || filerow > ey) return 0;
    if (filerow > sy && filerow < ey) return 1;
    if (sy == ey) return (x >= sx && x <= ex);
    if (filerow == sy) return (x >= sx);
    if (filerow == ey) return (x <= ex);
    
    return 0;
}

void editorDrawRows(struct abuf *ab) {
    int gutter_width = editorGetGutterWidth();
    int gutter_cols = gutter_width > 0 ? gutter_width + 1 : 0;
    int text_cols = E.screencols - gutter_cols;
    if (text_cols < 1) text_cols = 1;
    int y;
    for (y = 0; y < E.screenrows; y++) {
        int filerow = y + E.rowoff;
        if (filerow >= E.numrows) {
            if (E.numrows == 0 && y >= E.screenrows / 3 && y < E.screenrows / 3 + 9) {
                abAppend(ab, "\x1b[2m~\x1b[m", strlen("\x1b[2m~\x1b[m"));
                const char *welcome[] = {
                    "VIDERE v0.1.0",
                    "",
                    "videre is open source and freely distributable",
                    "https://github.com/euxaristia/videre",
                    "",
                    "type  :q<Enter>               to exit         ",
                    "type  :help<Enter>            for help        ",
                    "",
                    "Maintainer: euxaristia",
                };
                int msg_idx = y - E.screenrows / 3;
                int welcomelen = strlen(welcome[msg_idx]);
                if (welcomelen > text_cols) welcomelen = text_cols;
                int padding = (text_cols - welcomelen) / 2;
                while (padding-- > 0) abAppend(ab, " ", 1);
                abAppend(ab, welcome[msg_idx], welcomelen);
            } else {
                abAppend(ab, "\x1b[2m~\x1b[m", strlen("\x1b[2m~\x1b[m"));
            }
        } else {
            if (gutter_width > 0) {
                char gutter[64];
                int glen = snprintf(gutter, sizeof(gutter), "\x1b[2m%*d \x1b[m", gutter_width, filerow + 1);
                abAppend(ab, gutter, glen);
            }
            int row_coloff = E.coloff;
            if (row_coloff > E.row[filerow].size) row_coloff = E.row[filerow].size;
            row_coloff = editorSnapToUtf8Boundary(E.row[filerow].chars, E.row[filerow].size, row_coloff);

            int bytes_avail = E.row[filerow].size - row_coloff;
            if (bytes_avail < 0) bytes_avail = 0;
            
            char *chars = &E.row[filerow].chars[row_coloff];
            unsigned char *hl = &E.row[filerow].hl[row_coloff];
            int current_color = -1;
            int current_bg = -1;  // Track background color
            int current_reverse = 0;  // Track reverse video (for search highlighting)
            int j = 0;
            int rendered_cols = 0;
            while (j < bytes_avail) {
                uint32_t cp = 0;
                int clen = editorDecodeUtf8(&chars[j], bytes_avail - j, &cp);
                int char_width = editorCodepointWidth(cp);
                if (char_width < 0) char_width = 1;

                if (rendered_cols + char_width > text_cols) break;

                int is_selected = 0;
                for (int k = 0; k < clen; k++) {
                    if (editorRowIsSelected(filerow, j + row_coloff + k)) {
                        is_selected = 1;
                        break;
                    }
                }
                int bg_color = -1;  // -1 means no special background
                int is_reverse = 0;  // 0 = normal, 1 = reverse video (search highlight)
                
                // Determine background color for selection
                if (is_selected) {
                    bg_color = 242;  // Visual selection background
                }
                
                // Search match highlighting (reverse video like neovim)
                if (hl[j] == HL_MATCH) {
                    is_reverse = 1;  // Reverse video for other matches
                } else if (hl[j] == HL_MATCH_CURSOR) {
                    is_reverse = 2;  // Reverse video for current match (brighter)
                }

                int color = editorSyntaxToColor(hl[j]);
                
                // Handle reverse video for search highlighting
                if (is_reverse != current_reverse) {
                    current_reverse = is_reverse;
                    if (is_reverse == 1) {
                        // Other matches: reverse video with dark background
                        abAppend(ab, "\x1b[7m", 4);  // Enable reverse video
                        abAppend(ab, "\x1b[48;5;94m", 11);  // Dark brown background
                        current_bg = 94;
                    } else if (is_reverse == 2) {
                        // Current match: reverse video with bright yellow background
                        abAppend(ab, "\x1b[7m", 4);  // Enable reverse video
                        abAppend(ab, "\x1b[48;5;220m", 11);  // Bright yellow/gold background
                        current_bg = 220;
                    } else {
                        abAppend(ab, "\x1b[27m", 5);  // Disable reverse video
                    }
                }
                
                // Change color if needed (only if not in reverse video mode)
                if (!is_reverse && color != current_color) {
                    current_color = color;
                    char buf[16];
                    int clen = snprintf(buf, sizeof(buf), "\x1b[%dm", color);
                    abAppend(ab, buf, clen);
                }
                
                // Change background if needed (only if not in reverse video mode)
                if (!is_reverse && bg_color != current_bg) {
                    current_bg = bg_color;
                    if (bg_color >= 0) {
                        char buf[16];
                        int clen = snprintf(buf, sizeof(buf), "\x1b[48;5;%dm", bg_color);
                        abAppend(ab, buf, clen);
                    } else {
                        abAppend(ab, "\x1b[49m", 5); // Reset background
                    }
                }
                
                abAppend(ab, &chars[j], clen);
                rendered_cols += char_width;
                j += clen;
            }
            abAppend(ab, "\x1b[39m", 5);
            abAppend(ab, "\x1b[49m", 5);  // Reset background
            abAppend(ab, "\x1b[27m", 5);   // Reset reverse video
        }

        abAppend(ab, "\x1b[K", 3);
        abAppend(ab, "\r\n", 2);
    }
}

void editorDrawStatusBar(struct abuf *ab) {
    // Neovim-style status bar: grey background (ANSI 250) with dark grey text (ANSI 240) for better contrast
    abAppend(ab, "\x1b[48;5;250m", 11);
    abAppend(ab, "\x1b[38;5;240m", 11);
    
    char status[80], rstatus[80];
    
    // Left side: filename and modification flag (neovim format)
    int len = snprintf(status, sizeof(status), " %s%s%s%s",
        E.filename ? E.filename : "[No Name]",
        E.dirty ? " [+]" : "",
        E.git_status[0] ? " [" : "",
        E.git_status[0] ? E.git_status : "");
    if (E.git_status[0]) {
        int glen = strlen(status);
        if (glen < (int)sizeof(status) - 1) {
            status[glen] = ']';
            status[glen+1] = '\0';
            len = glen + 1;
        }
    }
    if (len > (int)sizeof(status) - 1) len = sizeof(status) - 1;
    
    // Right side: cursor position and scroll indicator (neovim format)
    char *pos_indicator;
    if (E.numrows == 0) {
        pos_indicator = "All";
    } else if (E.rowoff == 0) {
        pos_indicator = "Top";
    } else if (E.rowoff + E.screenrows >= E.numrows) {
        pos_indicator = "Bot";
    } else {
        static char pct_buf[8];
        int pct = (E.rowoff * 100) / (E.numrows - E.screenrows);
        snprintf(pct_buf, sizeof(pct_buf), "%d%%", pct);
        pos_indicator = pct_buf;
    }
    
    // Neovim-style ruler spacing: padded location field before Top/Bot/All/%.
    char loc[32];
    snprintf(loc, sizeof(loc), "%d,%d-1", E.cy + 1, E.cx + 1);
    int rlen = snprintf(rstatus, sizeof(rstatus), " %-14s %s", loc, pos_indicator);

    // Truncate left side if it's too long (neovim-style spacing)
    if (len > E.screencols - rlen) {
        len = E.screencols - rlen;
        if (len < 0) len = 0;
    }
    
    abAppend(ab, status, len);
    
    // Fill middle with spaces
    while (len < E.screencols - rlen) {
        abAppend(ab, " ", 1);
        len++;
    }
    
    // Add right side
    abAppend(ab, rstatus, rlen);
    abAppend(ab, "\x1b[m", 3);
    abAppend(ab, "\r\n", 2);
}

void editorDrawMessageBar(struct abuf *ab) {
    abAppend(ab, "\x1b[K", 3);
    
    // Show mode indicator or status message
    char *mode_msg = "";
    if (E.statusmsg[0] == '\0' || time(NULL) - E.statusmsg_time >= 5) {
        // Show mode indicator when no active message
        if (E.mode == MODE_INSERT) {
            mode_msg = "-- INSERT --";
        } else if (E.mode == MODE_VISUAL) {
            mode_msg = "-- VISUAL --";
        } else if (E.mode == MODE_VISUAL_LINE) {
            mode_msg = "-- VISUAL LINE --";
        }
    }
    
    if (mode_msg[0] != '\0') {
        // Display mode indicator on the left (standard editor behavior)
        abAppend(ab, mode_msg, strlen(mode_msg));
    } else {
        // Display status message if active
        int msglen = strlen(E.statusmsg);
        if (msglen > E.screencols) msglen = E.screencols;
        if (msglen && time(NULL) - E.statusmsg_time < 5) {
            abAppend(ab, E.statusmsg, msglen);
        }
    }
}

// --- Context Menu ---

char *menu_items[] = {
    " Cut       ",
    " Copy      ",
    " Paste     ",
    " Select All ",
    "----------- ",
    " Undo      ",
    " Redo      "
};
#define MENU_COUNT (int)(sizeof(menu_items) / sizeof(menu_items[0]))

void editorDrawContextMenu(struct abuf *ab) {
    if (!E.menu_open) return;

    int x = E.menu_x;
    int y = E.menu_y;
    
    // Ensure menu stays within screen bounds
    int menu_width = 13;
    int menu_height = MENU_COUNT + 2;
    
    if (x + menu_width > E.screencols) x = E.screencols - menu_width;
    if (y + menu_height > E.screenrows) y = E.screenrows - menu_height;
    if (x < 1) x = 1;
    if (y < 1) y = 1;

    char buf[64];
    // Draw shadow/border and items
    // Dark background (235), Medium grey border (239)
    snprintf(buf, sizeof(buf), "\x1b[%d;%dH", y, x);
    abAppend(ab, buf, strlen(buf));
    
    char *top_border = "\x1b[48;5;235m\x1b[38;5;239m┌───────────┐";
    abAppend(ab, top_border, strlen(top_border));

    for (int i = 0; i < MENU_COUNT; i++) {
        snprintf(buf, sizeof(buf), "\x1b[%d;%dH", y + i + 1, x);
        abAppend(ab, buf, strlen(buf));
        
        if (i == E.menu_selected) {
            // Selected item: Blue background (24), White text (255)
            abAppend(ab, "\x1b[48;5;24m\x1b[38;5;255m│", strlen("\x1b[48;5;24m\x1b[38;5;255m│"));
            if (i == 4) { // Separator
                abAppend(ab, "───────────", strlen("───────────"));
            } else {
                abAppend(ab, menu_items[i], strlen(menu_items[i]));
            }
            abAppend(ab, "│", strlen("│"));
        } else {
            // Normal item: Dark background (235), Light grey text (252)
            abAppend(ab, "\x1b[48;5;235m\x1b[38;5;239m│", strlen("\x1b[48;5;235m\x1b[38;5;239m│"));
            abAppend(ab, "\x1b[38;5;252m", strlen("\x1b[38;5;252m"));
            
            if (i == 4) { // Separator
                abAppend(ab, "\x1b[38;5;239m───────────", strlen("\x1b[38;5;239m───────────"));
            } else {
                abAppend(ab, menu_items[i], strlen(menu_items[i]));
            }
            abAppend(ab, "\x1b[38;5;239m│", strlen("\x1b[38;5;239m│"));
        }
    }

    snprintf(buf, sizeof(buf), "\x1b[%d;%dH", y + MENU_COUNT + 1, x);
    abAppend(ab, buf, strlen(buf));
    char *bottom_border = "\x1b[48;5;235m\x1b[38;5;239m└───────────┘\x1b[m";
    abAppend(ab, bottom_border, strlen(bottom_border));
}

void editorRefreshScreen() {
    editorScroll();

    struct abuf ab = ABUF_INIT;

    abAppend(&ab, "\x1b[?25l", 6);
    abAppend(&ab, "\x1b[H", 3);

    editorDrawRows(&ab);
    editorDrawStatusBar(&ab);
    editorDrawMessageBar(&ab);
    
    if (E.menu_open) {
        editorDrawContextMenu(&ab);
    }

    int gutter_width = editorGetGutterWidth();
    int gutter_cols = gutter_width > 0 ? gutter_width + 1 : 0;
    char buf[32];
    int cursor_col = 1 + gutter_cols;
    if (E.cy >= 0 && E.cy < E.numrows) {
        int start = E.coloff;
        if (start < 0) start = 0;
        if (start > E.row[E.cy].size) start = E.row[E.cy].size;
        start = editorSnapToUtf8Boundary(E.row[E.cy].chars, E.row[E.cy].size, start);
        int end = E.cx;
        if (end < start) end = start;
        if (end > E.row[E.cy].size) end = E.row[E.cy].size;
        end = editorSnapToUtf8Boundary(E.row[E.cy].chars, E.row[E.cy].size, end);
        cursor_col += editorDisplayWidthBytes(&E.row[E.cy].chars[start], end - start);
    }
    snprintf(buf, sizeof(buf), "\x1b[%d;%dH", (E.cy - E.rowoff) + 1, cursor_col);
    
    if (E.statusmsg[0] == ':') {
         snprintf(buf, sizeof(buf), "\x1b[%d;%dH", E.screenrows + 2, (int)strlen(E.statusmsg) + 1);
    }

    abAppend(&ab, buf, strlen(buf));
    abAppend(&ab, "\x1b[?25h", 6);

    write(STDOUT_FILENO, ab.b, ab.len);
    abFree(&ab);
}

// --- Input Handling ---

int editorHandleMouse() {
    static int last_click_x = -1, last_click_y = -1;
    static struct timespec last_click_time = {0, 0};
    
    int b = E.mouse_b;
    int x = E.mouse_x;
    int y = E.mouse_y;

    if (E.menu_open) {
        int menu_width = 13;
        int menu_height = MENU_COUNT + 2;
        int mx = E.menu_x;
        int my = E.menu_y;
        if (mx + menu_width > E.screencols) mx = E.screencols - menu_width;
        if (my + menu_height > E.screenrows) my = E.screenrows - menu_height;
        if (mx < 1) mx = 1;
        if (my < 1) my = 1;

        int prev_selected = E.menu_selected;
        if (x >= mx && x < mx + menu_width && y >= my && y < my + menu_height) {
            int item_idx = y - my - 1;
            if (item_idx >= 0 && item_idx < MENU_COUNT) {
                E.menu_selected = item_idx;
            } else {
                E.menu_selected = -1;
            }
        } else {
            E.menu_selected = -1;
        }

        if (b == MOUSE_LEFT) {
            int item_idx = E.menu_selected;
            if (item_idx >= 0 && item_idx < MENU_COUNT) {
                // Execute menu action
                if (strstr(menu_items[item_idx], " Cut")) {
                    if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                        editorYank(E.sel_sx, E.sel_sy, E.cx, E.cy, E.mode == MODE_VISUAL_LINE);
                        editorDeleteRange(E.sel_sx, E.sel_sy, E.cx, E.cy);
                        E.mode = MODE_NORMAL;
                        E.sel_sx = E.sel_sy = -1;
                    }
                } else if (strstr(menu_items[item_idx], " Copy")) {
                    if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                        editorYank(E.sel_sx, E.sel_sy, E.cx, E.cy, E.mode == MODE_VISUAL_LINE);
                        E.mode = MODE_NORMAL;
                        E.sel_sx = E.sel_sy = -1;
                    }
                } else if (strstr(menu_items[item_idx], " Paste")) {
                    editorPaste();
                } else if (strstr(menu_items[item_idx], " Select All")) {
                    editorSelectAll();
                } else if (strstr(menu_items[item_idx], " Undo")) {
                    editorUndo();
                } else if (strstr(menu_items[item_idx], " Redo")) {
                    editorRedo();
                }
            }
            E.menu_open = 0;
            return 1;
        } else if (b == MOUSE_RIGHT) {
            // Right-click while menu is open: move the menu
            E.menu_x = x;
            E.menu_y = y;
            E.menu_selected = -1;
            return 1;
        } else if ((b & 0x80) || (b & MOUSE_DRAG)) {
            // Just movement or release: refresh only if selection changed
            return (E.menu_selected != prev_selected);
        } else {
            // Click outside menu: close it
            E.menu_open = 0;
            return 1;
        }
    }

    if (b & 0x40) { // Wheel
        if ((b & 0x3) == 0) { // Up
            int times = 3;
            while (times--) {
                if (E.rowoff > 0) {
                    E.rowoff--;
                    if (E.cy > 0) E.cy--;
                }
            }
        } else if ((b & 0x3) == 1) { // Down
            int times = 3;
            while (times--) {
                if (E.rowoff + E.screenrows < E.numrows) {
                    E.rowoff++;
                    if (E.cy < E.numrows - 1) E.cy++;
                }
            }
        }
        E.preferredColumn = E.cx;
        return 1;
    }

    if (b & 0x80) { // Release
        E.is_dragging = 0;
        return 0; // Release doesn't need refresh usually unless we were dragging
    }

    int prev_cx = E.cx, prev_cy = E.cy;

    // Only process motion if dragging
    if (b == (MOUSE_LEFT | MOUSE_DRAG)) {
        if (!E.is_dragging) return 0;
        // Convert screen coordinates to buffer coordinates
        int filerow = y - 1 + E.rowoff;
        int gutter_width = editorGetGutterWidth();
        int gutter_cols = gutter_width > 0 ? gutter_width + 1 : 0;
        int text_x = x - gutter_cols;
        
        if (filerow >= 0 && filerow < E.numrows) {
            E.cy = filerow;
            int row_coloff = E.coloff;
            if (row_coloff > E.row[E.cy].size) row_coloff = E.row[E.cy].size;
            row_coloff = editorSnapToUtf8Boundary(E.row[E.cy].chars, E.row[E.cy].size, row_coloff);
            int target_display_col = (text_x <= 0) ? 0 : (text_x - 1);
            int rel_byte = editorByteIndexFromDisplayCol(&E.row[E.cy].chars[row_coloff], E.row[E.cy].size - row_coloff, target_display_col);
            E.cx = row_coloff + rel_byte;
            if (E.mode != MODE_INSERT && E.row[E.cy].size > 0 && E.cx >= E.row[E.cy].size) {
                E.cx = E.row[E.cy].size - 1;
            }
        }
        
        if (E.mode == MODE_NORMAL) {
            E.mode = MODE_VISUAL;
        }
        return 1;
    }

    if (b == MOUSE_LEFT) {
        // Convert screen coordinates to buffer coordinates
        int filerow = y - 1 + E.rowoff;
        int gutter_width = editorGetGutterWidth();
        int gutter_cols = gutter_width > 0 ? gutter_width + 1 : 0;
        int text_x = x - gutter_cols;

        if (filerow >= 0 && filerow < E.numrows) {
            E.cy = filerow;
            int row_coloff = E.coloff;
            if (row_coloff > E.row[E.cy].size) row_coloff = E.row[E.cy].size;
            row_coloff = editorSnapToUtf8Boundary(E.row[E.cy].chars, E.row[E.cy].size, row_coloff);
            int target_display_col = (text_x <= 0) ? 0 : (text_x - 1);
            int rel_byte = editorByteIndexFromDisplayCol(&E.row[E.cy].chars[row_coloff], E.row[E.cy].size - row_coloff, target_display_col);
            E.cx = row_coloff + rel_byte;
            if (E.mode != MODE_INSERT && E.row[E.cy].size > 0 && E.cx >= E.row[E.cy].size) {
                E.cx = E.row[E.cy].size - 1;
            }
        }

        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        long long elapsed_ms = (now.tv_sec - last_click_time.tv_sec) * 1000LL +
                               (now.tv_nsec - last_click_time.tv_nsec) / 1000000LL;

        if (x == last_click_x && y == last_click_y && elapsed_ms < 500) {
            // Double-click: select word
            editorSelectWord();
            // Clear any dragging state to prevent accidental drag selection after double-click
            E.is_dragging = 0;
            if (E.mode != MODE_VISUAL && E.mode != MODE_VISUAL_LINE) {
                E.mode = MODE_VISUAL;  // Ensure we're in visual mode for the selected word
            }
        } else {
            // Single click: start dragging and reset selection
            E.is_dragging = 1;
            E.sel_sx = E.cx;
            E.sel_sy = E.cy;
            if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                E.mode = MODE_NORMAL;
                E.sel_sx = E.sel_sy = -1;
            }
        }
        last_click_x = x;
        last_click_y = y;
        last_click_time = now;
        return 1;
    }
    // Handle right click - open context menu
    else if (b == MOUSE_RIGHT) {
        E.menu_open = 1;
        E.menu_x = x;
        E.menu_y = y;
        E.menu_selected = -1;
        return 1;
    }
    
    return (E.cx != prev_cx || E.cy != prev_cy);
}

int editorProcessKeypress() {
    static int quit_times = 1;
    int c = readKey();
    
    if (E.menu_open && c != MOUSE_EVENT) {
        E.menu_open = 0;
        if (c == '\x1b') return 1;
        // Fall through to process key if not ESC
    }
    
    if (c == MOUSE_EVENT) {
        return editorHandleMouse();
    }

    if (c == PASTE_EVENT) {
        if (E.paste_buffer) {
            for (int i = 0; E.paste_buffer[i]; i++) {
                if (E.paste_buffer[i] == '\r' || E.paste_buffer[i] == '\n') {
                    editorInsertNewline();
                    if (E.paste_buffer[i] == '\r' && E.paste_buffer[i+1] == '\n') i++;
                } else {
                    editorInsertChar(E.paste_buffer[i]);
                }
            }
            free(E.paste_buffer);
            E.paste_buffer = NULL;
        }
        return 1;
    }

    if (E.mode == MODE_INSERT) {
        switch (c) {
            case '\r':
                editorInsertNewline();
                break;
            case '\x1b':
                E.mode = MODE_NORMAL;
                editorSetStatusMessage("");
                if (E.cx > 0) E.cx--;
                return 1;
            case 127:
            case 8: 
            case BACKSPACE:
                editorDelChar();
                break;
            case DEL_KEY:
                editorMoveCursor(ARROW_RIGHT);
                editorDelChar();
                break;
            case ARROW_UP:
            case ARROW_DOWN:
            case ARROW_LEFT:
            case ARROW_RIGHT:
                editorMoveCursor(c);
                break;
            default:
                if (!iscntrl(c)) {
                    editorInsertChar(c);
                }
                break;
        }
    } else {
        // Normal / Visual Mode
        switch (c) {
            case 'i':
                E.mode = MODE_INSERT;
                E.sel_sx = E.sel_sy = -1;
                editorSetStatusMessage("-- INSERT --");
                break;

            case 'v':
                if (E.mode == MODE_VISUAL) {
                    E.mode = MODE_NORMAL;
                    E.sel_sx = E.sel_sy = -1;
                } else {
                    E.mode = MODE_VISUAL;
                    E.sel_sx = E.cx;
                    E.sel_sy = E.cy;
                }
                break;

            case 'V':
                if (E.mode == MODE_VISUAL_LINE) {
                    E.mode = MODE_NORMAL;
                    E.sel_sx = E.sel_sy = -1;
                } else {
                    E.mode = MODE_VISUAL_LINE;
                    E.sel_sx = 0;
                    E.sel_sy = E.cy;
                }
                break;

            case 'u':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorChangeCase(0);  // lowercase
                } else {
                    editorUndo();
                }
                break;

            case 18: // CTRL-R
                editorRedo();
                break;
            
            case 1: // CTRL-A
                editorIncrementNumber(1);
                break;
            
            case 24: // CTRL-X
                editorIncrementNumber(-1);
                break;
            
            case 'U':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorChangeCase(1);  // uppercase
                }
                break;

            case 'y':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorYank(E.sel_sx, E.sel_sy, E.cx, E.cy, E.mode == MODE_VISUAL_LINE);
                    E.mode = MODE_NORMAL;
                    E.sel_sx = E.sel_sy = -1;
                    editorSetStatusMessage("Yanked");
                }
                break;

            case 'p':
                editorPaste();
                break;

            case '\x1b':
                E.mode = MODE_NORMAL;
                E.sel_sx = E.sel_sy = -1;
                editorSetStatusMessage("");
                break;

            case 'd':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorYank(E.sel_sx, E.sel_sy, E.cx, E.cy, E.mode == MODE_VISUAL_LINE);
                    editorDeleteRange(E.sel_sx, E.sel_sy, E.cx, E.cy);
                    E.mode = MODE_NORMAL;
                    E.sel_sx = E.sel_sy = -1;
                }
                break;

            case 'x':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorYank(E.sel_sx, E.sel_sy, E.cx, E.cy, E.mode == MODE_VISUAL_LINE);
                    editorDeleteRange(E.sel_sx, E.sel_sy, E.cx, E.cy);
                    E.mode = MODE_NORMAL;
                    E.sel_sx = E.sel_sy = -1;
                } else {
                    editorMoveCursor(ARROW_RIGHT);
                    editorDelChar();
                }
                break;

            case 3: // CTRL-C
                if (E.dirty && quit_times > 0) {
                    editorSetStatusMessage("WARNING!!! File has unsaved changes. "
                        "Press Ctrl-C %d more times to quit.", quit_times);
                    quit_times--;
                    return 1;
                }
                exit(0);
                break;

            case ':':
                {
                    char *cmd = editorPrompt(":%s", NULL);
                    if (cmd) {
                        if (strcmp(cmd, "q") == 0) {
                            if (E.dirty) {
                                editorSetStatusMessage("No write since last change (add ! to override)");
                            } else {
                                exit(0);
                            }
                        } else if (strcmp(cmd, "q!") == 0) {
                            exit(0);
                        } else if (strcmp(cmd, "w") == 0) {
                            editorSave();
                        } else if (strcmp(cmd, "wq") == 0) {
                            editorSave();
                            exit(0);
                        } else if (strcmp(cmd, "help") == 0) {
                            editorSetStatusMessage("Help not yet implemented");
                        } else {
                            editorSetStatusMessage("Not an editor command: %s", cmd);
                        }
                        free(cmd);
                    }
                }
                break;

            case '/':
                editorFind();
                break;

            case HOME_KEY:
                E.cx = 0;
                break;
            case END_KEY:
                if (E.cy < E.numrows)
                    E.cx = E.row[E.cy].size;
                break;

            case PAGE_UP:
            case PAGE_DOWN:
                {
                    if (c == PAGE_UP) {
                        E.cy = E.rowoff;
                    } else {
                        E.cy = E.rowoff + E.screenrows - 1;
                        if (E.cy > E.numrows) E.cy = E.numrows;
                    }
                    
                    int times = E.screenrows;
                    while (times--)
                        editorMoveCursor(c == PAGE_UP ? ARROW_UP : ARROW_DOWN);
                }
                break;

            case ARROW_UP:
            case ARROW_DOWN:
            case ARROW_LEFT:
            case ARROW_RIGHT:
            case 'h':
            case 'j':
            case 'k':
            case 'l':
                {
                    int key = c;
                    if (c == 'h') key = ARROW_LEFT;
                    if (c == 'j') key = ARROW_DOWN;
                    if (c == 'k') key = ARROW_UP;
                    if (c == 'l') key = ARROW_RIGHT;
                    editorMoveCursor(key);
                }
                break;
            
            // Character search commands
            case 'f':
            case 'F':
            case 't':
            case 'T':
                {
                    // Read the next character to search for
                    int search_char = readKey();
                    if (search_char != '\x1b' && !iscntrl(search_char)) {
                        int direction = (c == 'f' || c == 't') ? 1 : -1;
                        int till = (c == 't' || c == 'T') ? 1 : 0;
                        
                        if (till) {
                            editorFindCharTill(search_char, direction);
                        } else {
                            editorFindChar(search_char, direction);
                        }
                        editorSetStatusMessage("Found %c at %d,%d", search_char, E.cy + 1, E.cx + 1);
                    }
                }
                break;
            
            case ';':
                // Repeat last character search in same direction
                editorRepeatCharSearch();
                break;
            
            case ',':
                // Repeat last character search in opposite direction
                if (E.last_search_char != '\0') {
                    editorFindChar(E.last_search_char, -1);
                }
                break;
            
            // Word motions
            case 'w':
                editorMoveWordForward(0);  // word
                break;
            case 'W':
                editorMoveWordForward(1);  // WORD
                break;
            case 'b':
                editorMoveWordBackward(0);  // word
                break;
            case 'B':
                editorMoveWordBackward(1);  // WORD
                break;
            case 'e':
                editorMoveWordEnd(0);  // word
                break;
            case 'E':
                editorMoveWordEnd(1);  // WORD
                break;
            
            case '%':
                editorMatchBracket();
                break;
            
            case 'n':
                editorFindNext(1);  // Next match
                break;
            
            case 'N':
                editorFindNext(-1);  // Previous match
                break;
            
            case 'm':
                {
                    int mark = readKey();
                    if (mark >= 'a' && mark <= 'z') {
                        editorSetMark(mark);
                    }
                }
                break;
            
            case '\'':
                {
                    int mark = readKey();
                    if (mark >= 'a' && mark <= 'z') {
                        editorGoToMark(mark);
                    }
                }
                break;
            
            case 'g':
                {
                    int next_char = readKey();
                    if (next_char == 'g') {
                        editorMoveToFileStart();
                    }
                }
                break;
            
            case '0':
                editorMoveToLineStart();
                break;
            
            case '^':
                editorMoveToFirstNonWhitespace();
                break;
            
            case '$':
                editorMoveToLineEnd();
                break;
            
            case 'G':
                editorMoveToFileEnd();
                break;
            
            case '{':
                editorMoveToPreviousParagraph();
                break;
            
            case '}':
                editorMoveToNextParagraph();
                break;
            
            // Visual mode operators
            case '>':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorIndent(1);
                }
                break;
            
            case '<':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    editorIndent(0);
                }
                break;
        }
    }

    quit_times = 1;
    return 1;
}

int main(int argc, char *argv[]) {
    setlocale(LC_CTYPE, "");
    initEditor();
    enableRawMode();
    if (argc >= 2) {
        editorOpen(argv[1]);
        E.filename = strdup(argv[1]);
    }

    // Don't show persistent help text - non-standard
// editorSetStatusMessage("HELP: :q = quit | i = insert | :w = save");

    editorRefreshScreen(); // Initial refresh
    while (1) {
        if (editorProcessKeypress()) {
            editorRefreshScreen();
        }
    }
    return 0;
}
