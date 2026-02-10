#ifndef VIDERE_H
#define VIDERE_H

#include <termios.h>
#include <unistd.h>
#include <time.h>

// Input Key Mapping
enum editorKey {
    BACKSPACE = 1000,
    ARROW_LEFT,
    ARROW_RIGHT,
    ARROW_UP,
    ARROW_DOWN,
    DEL_KEY,
    HOME_KEY,
    END_KEY,
    PAGE_UP,
    PAGE_DOWN
};

enum editorMode {
    MODE_NORMAL,
    MODE_INSERT,
    MODE_COMMAND
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
    int mode;
    char *search_pattern;
    int last_match;
    int search_direction;
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
void editorSave();
void editorFind();
void editorUpdateRow(erow *row);
void editorInsertChar(int c);
void editorInsertNewline();
void editorDelChar();
void editorRowInsertChar(erow *row, int at, int c);
void editorRowDelChar(erow *row, int at);
void editorFreeRow(erow *row);
void editorDelRow(int at);
void editorInsertRow(int at, char *s, size_t len);

void abAppend(struct abuf *ab, const char *s, int len);
void abFree(struct abuf *ab);
void editorSetStatusMessage(const char *fmt, ...);
char *editorPrompt(char *prompt, void (*callback)(char *, int));
void editorRefreshScreen();

#endif
