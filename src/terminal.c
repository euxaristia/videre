#include "videre.h"
#include "terminal.h"
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

EditorConfig E;
static int raw_mode_enabled = 0;

void die(const char *s) {
    // Force terminal cleanup before exit
    write(STDOUT_FILENO, "\x1b[?2004l", 8); // Disable bracketed paste
    write(STDOUT_FILENO, "\x1b[?1006l\x1b[?1003l", 16);
    write(STDOUT_FILENO, "\x1b[?1049l", 8);
    write(STDOUT_FILENO, "\x1b[?25h", 6);
    
    perror(s);
    exit(1);
}

void disableRawMode() {
    if (!raw_mode_enabled) return;
    
    tcsetattr(STDIN_FILENO, TCSANOW, &E.orig_termios);
    
    // Leave alternate screen, disable mouse, disable bracketed paste, show cursor
    write(STDOUT_FILENO, "\x1b[?2004l", 8);
    write(STDOUT_FILENO, "\x1b[?1006l\x1b[?1003l", 16);
    write(STDOUT_FILENO, "\x1b[?1049l", 8);
    write(STDOUT_FILENO, "\x1b[?25h", 6);
}

void enableRawMode() {
    if (tcgetattr(STDIN_FILENO, &E.orig_termios) == -1) {
        // Not a terminal, skip raw mode setup
        raw_mode_enabled = 0;
        return;
    }
    raw_mode_enabled = 1;
    atexit(disableRawMode);

    struct termios raw = E.orig_termios;
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag |= (CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 1;

    if (tcsetattr(STDIN_FILENO, TCSANOW, &raw) == -1) die("tcsetattr");

    // Enter alternate screen, enable mouse, enable bracketed paste, clear screen
    write(STDOUT_FILENO, "\x1b[?1049h", 8);
    write(STDOUT_FILENO, "\x1b[?1003h\x1b[?1006h", 16);
    write(STDOUT_FILENO, "\x1b[?2004h", 8);
    write(STDOUT_FILENO, "\x1b[2J", 4);
    write(STDOUT_FILENO, "\x1b[H", 3);
}

int readKey() {
    int nread;
    char c;
    while ((nread = read(STDIN_FILENO, &c, 1)) != 1) {
        if (nread == -1 && errno != EAGAIN) die("read");
    }

    if (c == '\x1b') {
        char seq[32];
        int i = 0;
        
        // Read the rest of the sequence with a timeout
        while (i < (int)sizeof(seq) - 1) {
            if (read(STDIN_FILENO, &seq[i], 1) != 1) break;
            if (seq[i] == '~' || isalpha(seq[i]) || i > 10) {
                i++;
                break;
            }
            i++;
        }
        seq[i] = '\0';

        if (i == 0) return '\x1b';

        if (seq[0] == '[') {
            if (isdigit(seq[1])) {
                if (seq[i-1] == '~') {
                    if (strncmp(&seq[1], "200", 3) == 0) {
                        // Bracketed Paste Start: ESC [ 200 ~
                        size_t bufsize = 1024;
                        char *pbuf = malloc(bufsize);
                        size_t plen = 0;
                        
                        while (1) {
                            char pc;
                            if (read(STDIN_FILENO, &pc, 1) != 1) break;
                            if (pc == '\x1b') {
                                char endseq[8];
                                int ei = 0;
                                while (ei < 5) {
                                    if (read(STDIN_FILENO, &endseq[ei], 1) != 1) break;
                                    ei++;
                                }
                                endseq[ei] = '\0';
                                if (strcmp(endseq, "[201~") == 0) break;
                                
                                // Not the end sequence, put ESC back? 
                                // Simplified: just append ESC and the sequence
                                if (plen + ei + 2 > bufsize) {
                                    bufsize *= 2;
                                    pbuf = realloc(pbuf, bufsize);
                                }
                                pbuf[plen++] = '\x1b';
                                memcpy(&pbuf[plen], endseq, ei);
                                plen += ei;
                                continue;
                            }
                            
                            if (plen + 1 >= bufsize) {
                                bufsize *= 2;
                                pbuf = realloc(pbuf, bufsize);
                            }
                            pbuf[plen++] = pc;
                        }
                        pbuf[plen] = '\0';
                        if (E.paste_buffer) free(E.paste_buffer);
                        E.paste_buffer = pbuf;
                        return PASTE_EVENT;
                    }
                    
                    switch (seq[1]) {
                        case '1': return HOME_KEY;
                        case '3': return DEL_KEY;
                        case '4': return END_KEY;
                        case '5': return PAGE_UP;
                        case '6': return PAGE_DOWN;
                        case '7': return HOME_KEY;
                        case '8': return END_KEY;
                    }
                }
            } else {
                switch (seq[1]) {
                    case 'A': return ARROW_UP;
                    case 'B': return ARROW_DOWN;
                    case 'C': return ARROW_RIGHT;
                    case 'D': return ARROW_LEFT;
                    case 'H': return HOME_KEY;
                    case 'F': return END_KEY;
                    case '<': {
                        // SGR Mouse Protocol already started in seq
                        // Continue reading until m or M if not already read
                        int mi = i;
                        if (seq[mi-1] != 'm' && seq[mi-1] != 'M') {
                            while (mi < (int)sizeof(seq) - 1) {
                                if (read(STDIN_FILENO, &seq[mi], 1) != 1) break;
                                if (seq[mi] == 'm' || seq[mi] == 'M') {
                                    mi++;
                                    break;
                                }
                                mi++;
                            }
                            seq[mi] = '\0';
                        }
                        
                        int b, x, y;
                        if (sscanf(&seq[2], "%d;%d;%d", &b, &x, &y) == 3) {
                            E.mouse_b = b;
                            E.mouse_x = x;
                            E.mouse_y = y;
                            if (seq[mi-1] == 'm') E.mouse_b |= 0x80;
                            return MOUSE_EVENT;
                        }
                    }
                }
            }
        } else if (seq[0] == 'O') {
            switch (seq[1]) {
                case 'H': return HOME_KEY;
                case 'F': return END_KEY;
            }
        }

        return '\x1b';
    } else {
        return c;
    }
}

int getWindowSize(int *rows, int *cols) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
        // Fallback to environment variables if ioctl fails
        const char *env_cols = getenv("COLUMNS");
        const char *env_rows = getenv("LINES");
        if (env_cols && env_rows) {
            *cols = atoi(env_cols);
            *rows = atoi(env_rows);
            if (*cols > 0 && *rows > 0) return 0;
        }
        // Default fallback values
        *cols = 80;
        *rows = 24;
        return -1;
    } else {
        *cols = ws.ws_col;
        *rows = ws.ws_row;
        return 0;
    }
}

void editorScroll() {
    // Adjust row offset based on cursor position
    if (E.cy < E.rowoff) {
        E.rowoff = E.cy;
    }
    if (E.cy >= E.rowoff + E.screenrows) {
        E.rowoff = E.cy - E.screenrows + 1;
    }
    
    // Adjust column offset based on cursor position
    if (E.cx < E.coloff) {
        E.coloff = E.cx;
    }
    if (E.cx >= E.coloff + E.screencols) {
        E.coloff = E.cx - E.screencols + 1;
    }
}