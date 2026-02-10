#ifndef VIDERE_H
#define VIDERE_H

#include <termios.h>
#include <unistd.h>
#include <time.h>

// Input Key Mapping
enum editorKey {
    BACKSPACE = 127,
    ARROW_LEFT = 1000,
    ARROW_RIGHT,
    ARROW_UP,
    ARROW_DOWN,
    DEL_KEY,
    HOME_KEY,
    END_KEY,
    PAGE_UP,
    PAGE_DOWN
};

// Data Structures
typedef struct erow {
    int size;
    char *chars;
} erow;

typedef struct {
    int cx, cy;
    int rowoff;
    int coloff;
    int screenrows;
    int screencols;
    int numrows;
    erow *row;
    int dirty;
    char *filename;
    char statusmsg[80];
    time_t statusmsg_time;
    struct termios orig_termios;
} EditorConfig;

struct abuf {
    char *b;
    int len;
};

#define ABUF_INIT {NULL, 0}

// Globals
extern EditorConfig E;

// Prototypes
void die(const char *s);
void editorOpen(char *filename);
void editorUpdateRow(erow *row);
void abAppend(struct abuf *ab, const char *s, int len);
void abFree(struct abuf *ab);
void editorSetStatusMessage(const char *fmt, ...);
char *editorPrompt(char *prompt);
void editorRefreshScreen();

#endif
