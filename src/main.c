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
    E.row = NULL;
    E.dirty = 0;
    E.filename = NULL;
    E.statusmsg[0] = '\0';
    E.statusmsg_time = 0;
    E.mode = MODE_NORMAL;
    E.is_dragging = 0;
    E.sel_sx = E.sel_sy = -1;

    if (getWindowSize(&E.screenrows, &E.screencols) == -1) die("getWindowSize");
    if (E.screenrows < 3) E.screenrows = 1;
    else E.screenrows -= 2; 
}

// --- High Level Editing ---

void editorInsertChar(int c) {
    if (E.cy == E.numrows) {
        editorInsertRow(E.numrows, "", 0);
    }
    editorRowInsertChar(&E.row[E.cy], E.cx, c);
    E.cx++;
}

void editorInsertNewline() {
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
        E.row[E.cy - 1].chars[E.row[E.cy - 1].size] = '\0';
        editorUpdateRow(&E.row[E.cy - 1]);
        
        editorDelRow(E.cy);
        E.cy--;
    }
}

// --- Status Message ---

void editorSetStatusMessage(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(E.statusmsg, sizeof(E.statusmsg), fmt, ap);
    va_end(ap);
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

// --- Scrolling ---

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

// --- Rendering ---

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
    int y;
    for (y = 0; y < E.screenrows; y++) {
        int filerow = y + E.rowoff;
        if (filerow >= E.numrows) {
            if (E.numrows == 0 && y >= E.screenrows / 3 && y < E.screenrows / 3 + 9) {
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
                if (welcomelen > E.screencols) welcomelen = E.screencols;
                int padding = (E.screencols - welcomelen) / 2;
                if (padding) {
                    abAppend(ab, "~", 1);
                    padding--;
                }
                while (padding-- > 0) abAppend(ab, " ", 1);
                abAppend(ab, welcome[msg_idx], welcomelen);
            } else {
                abAppend(ab, "~", 1);
            }
        } else {
            int len = E.row[filerow].size - E.coloff;
            if (len < 0) len = 0;
            if (len > E.screencols) len = E.screencols;
            
            char *chars = &E.row[filerow].chars[E.coloff];
            unsigned char *hl = &E.row[filerow].hl[E.coloff];
            int current_color = -1;
            int j;
            for (j = 0; j < len; j++) {
                int is_selected = editorRowIsSelected(filerow, j + E.coloff);
                
                if (is_selected) {
                    abAppend(ab, "\x1b[48;5;242m", 11); // Visual selection background
                }

                int color = editorSyntaxToColor(hl[j]);
                if (color != current_color) {
                    current_color = color;
                    char buf[16];
                    int clen = snprintf(buf, sizeof(buf), "\x1b[%dm", color);
                    abAppend(ab, buf, clen);
                }
                abAppend(ab, &chars[j], 1);
                
                if (is_selected) {
                    abAppend(ab, "\x1b[49m", 5); // Reset background
                }
            }
            abAppend(ab, "\x1b[39m", 5);
        }

        abAppend(ab, "\x1b[K", 3);
        abAppend(ab, "\r\n", 2);
    }
}

void editorDrawStatusBar(struct abuf *ab) {
    abAppend(ab, "\x1b[7m", 4);
    char status[80], rstatus[80];
    
    char *mode_str = " NORMAL ";
    if (E.mode == MODE_INSERT) mode_str = " INSERT ";
    else if (E.mode == MODE_VISUAL) mode_str = " VISUAL ";
    else if (E.mode == MODE_VISUAL_LINE) mode_str = " V-LINE ";
    
    int len = snprintf(status, sizeof(status), "%s %s%s",
        mode_str,
        E.filename ? E.filename : "[No Name]",
        E.dirty ? " [+]" : "");
    if (len > (int)sizeof(status) - 1) len = sizeof(status) - 1;
    
    int rlen = snprintf(rstatus, sizeof(rstatus), "%d,%d-1 ",
        E.cy + 1, E.cx + 1);
    if (rlen > (int)sizeof(rstatus) - 1) rlen = sizeof(rstatus) - 1;

    if (len > E.screencols) len = E.screencols;
    abAppend(ab, status, len);
    
    while (len < E.screencols) {
        if (E.screencols - len == rlen) {
            abAppend(ab, rstatus, rlen);
            break;
        } else {
            abAppend(ab, " ", 1);
            len++;
        }
    }
    abAppend(ab, "\x1b[m", 3);
    abAppend(ab, "\r\n", 2);
}

void editorDrawMessageBar(struct abuf *ab) {
    abAppend(ab, "\x1b[K", 3);
    int msglen = strlen(E.statusmsg);
    if (msglen > E.screencols) msglen = E.screencols;
    if (msglen && time(NULL) - E.statusmsg_time < 5)
        abAppend(ab, E.statusmsg, msglen);
}

void editorRefreshScreen() {
    editorScroll();

    struct abuf ab = ABUF_INIT;

    abAppend(&ab, "\x1b[?25l", 6);
    abAppend(&ab, "\x1b[H", 3);

    editorDrawRows(&ab);
    editorDrawStatusBar(&ab);
    editorDrawMessageBar(&ab);

    char buf[32];
    snprintf(buf, sizeof(buf), "\x1b[%d;%dH", (E.cy - E.rowoff) + 1, (E.cx - E.coloff) + 1);
    
    if (E.statusmsg[0] == ':') {
         snprintf(buf, sizeof(buf), "\x1b[%d;%dH", E.screenrows + 2, (int)strlen(E.statusmsg) + 1);
    }

    abAppend(&ab, buf, strlen(buf));
    abAppend(&ab, "\x1b[?25h", 6);

    write(STDOUT_FILENO, ab.b, ab.len);
    abFree(&ab);
}

// --- Input Handling ---

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
            if (E.cy < E.numrows) {
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

void editorHandleMouse() {
    int b = E.mouse_b;
    int x = E.mouse_x;
    int y = E.mouse_y;

    if (b & 0x40) { // Wheel
        if ((b & 0x3) == 0) { // Up
            int times = 3;
            while (times--) {
                if (E.rowoff > 0) E.rowoff--;
            }
        } else if ((b & 0x3) == 1) { // Down
            int times = 3;
            while (times--) {
                if (E.rowoff + E.screenrows < E.numrows) E.rowoff++;
            }
        }
        return;
    }

    if (b & 0x80) { // Release
        E.is_dragging = 0;
        return;
    }

    // Convert screen coordinates to buffer coordinates
    int filerow = y - 1 + E.rowoff;
    int filecol = x - 1 + E.coloff;
    
    if (filerow >= 0 && filerow < E.numrows) {
        E.cy = filerow;
        if (filecol >= 0 && filecol <= E.row[E.cy].size) {
            E.cx = filecol;
        } else {
            E.cx = E.row[E.cy].size;
        }
    }

    if (b == MOUSE_LEFT) {
        E.is_dragging = 1;
        if (E.mode != MODE_VISUAL && E.mode != MODE_VISUAL_LINE) {
            E.sel_sx = E.cx;
            E.sel_sy = E.cy;
        }
    } else if (b == (MOUSE_LEFT | MOUSE_DRAG)) {
        if (E.mode == MODE_NORMAL) {
            E.mode = MODE_VISUAL;
        }
    }
}

void editorProcessKeypress() {
    static int quit_times = 1;
    int c = readKey();
    
    if (c == MOUSE_EVENT) {
        editorHandleMouse();
        return;
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
                break;
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

            case '\x1b':
                E.mode = MODE_NORMAL;
                E.sel_sx = E.sel_sy = -1;
                editorSetStatusMessage("");
                break;

            case 'x':
                if (E.mode == MODE_VISUAL || E.mode == MODE_VISUAL_LINE) {
                    // TODO: delete selection
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
                    return;
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
        }
    }

    quit_times = 1;
}

int main(int argc, char *argv[]) {
    initEditor();
    enableRawMode();
    if (argc >= 2) {
        editorOpen(argv[1]);
        E.filename = strdup(argv[1]);
    }

    editorSetStatusMessage("HELP: :q = quit | i = insert | :w = save");

    while (1) {
        editorRefreshScreen();
        editorProcessKeypress();
    }
    return 0;
}