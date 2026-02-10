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
        // Concatenate with previous row
        E.cx = E.row[E.cy - 1].size;
        // Need a row append function in rows.c or here
        // For simplicity, let's just do it here or add to rows.c
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

char *editorPrompt(char *prompt) {
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
            free(buf);
            return NULL;
        } else if (c == '\r') {
            if (buflen != 0) {
                editorSetStatusMessage("");
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
            if (len > 0) {
                abAppend(ab, &E.row[filerow].chars[E.coloff], len);
            }
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

void editorProcessKeypress() {
    static int quit_times = 1;
    int c = readKey();
    
    if (E.mode == MODE_INSERT) {
        switch (c) {
            case '\r':
                editorInsertNewline();
                break;
            case '\x1b':
                E.mode = MODE_NORMAL;
                editorSetStatusMessage("");
                // Move cursor back if at end of line to match vim
                if (E.cx > 0) E.cx--;
                break;
            case 127:
            case 8: // Ctrl-H
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
        // Normal Mode
        switch (c) {
            case 'i':
                E.mode = MODE_INSERT;
                editorSetStatusMessage("-- INSERT --");
                break;

            case 'a':
                E.mode = MODE_INSERT;
                editorSetStatusMessage("-- INSERT --");
                editorMoveCursor(ARROW_RIGHT);
                break;

            case 'x':
                editorMoveCursor(ARROW_RIGHT);
                editorDelChar();
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
                    char *cmd = editorPrompt(":%s");
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