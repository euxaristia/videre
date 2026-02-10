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
    write(STDOUT_FILENO, "\x1b[?1006l\x1b[?1003l", 16);
    write(STDOUT_FILENO, "\x1b[?1049l", 8);
    write(STDOUT_FILENO, "\x1b[?25h", 6);
    
    perror(s);
    exit(1);
}

void disableRawMode() {
    if (!raw_mode_enabled) return;
    
    tcsetattr(STDIN_FILENO, TCSANOW, &E.orig_termios);
    
    // Leave alternate screen, disable mouse, show cursor
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

    // Enter alternate screen, enable mouse (any event mode + SGR), clear screen
    write(STDOUT_FILENO, "\x1b[?1049h", 8);
    write(STDOUT_FILENO, "\x1b[?1003h\x1b[?1006h", 16);
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
        char seq[3];

        if (read(STDIN_FILENO, &seq[0], 1) != 1) return '\x1b';
        if (read(STDIN_FILENO, &seq[1], 1) != 1) return '\x1b';

        if (seq[0] == '[') {
            if (seq[1] >= '0' && seq[1] <= '9') {
                if (read(STDIN_FILENO, &seq[2], 1) != 1) return '\x1b';
                if (seq[2] == '~') {
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
                        // SGR Mouse Protocol: <button;x;y;m/M
                        char mouse_seq[64];
                        int mi = 0;
                        int max_reads = 100; // Prevent infinite loops
                        
                        while (mi < 63 && max_reads-- > 0) {
                            if (read(STDIN_FILENO, &mouse_seq[mi], 1) != 1) break;
                            
                            // Validate input - only allow digits, semicolons, and m/M
                            if (!isdigit(mouse_seq[mi]) && mouse_seq[mi] != ';' && 
                                mouse_seq[mi] != 'm' && mouse_seq[mi] != 'M') {
                                // Invalid character, abort parsing
                                return '\x1b';
                            }
                            
                            if (mouse_seq[mi] == 'm' || mouse_seq[mi] == 'M') {
                                mi++;
                                break;
                            }
                            mi++;
                        }
                        
                        // Ensure we don't overflow
                        if (mi >= 63) mi = 63;
                        mouse_seq[mi] = '\0';
                        
                        // Validate mouse sequence format before parsing
                        int b, x, y;
                        if (mi > 0 && sscanf(mouse_seq, "%d;%d;%d", &b, &x, &y) == 3) {
                            // Validate bounds
                            if (b >= 0 && b <= 255 && x >= 0 && x <= 10000 && y >= 0 && y <= 10000) {
                                E.mouse_b = b;
                                E.mouse_x = x;
                                E.mouse_y = y;
                                if (mouse_seq[mi-1] == 'm') E.mouse_b |= 0x80; // Release bit
                                return MOUSE_EVENT;
                            }
                        }
                        return '\x1b';
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
