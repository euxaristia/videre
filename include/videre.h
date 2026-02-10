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
    PAGE_DOWN,
    MOUSE_EVENT
};

enum editorMode {
    MODE_NORMAL,
    MODE_INSERT,
    MODE_COMMAND,
    MODE_VISUAL,
    MODE_VISUAL_LINE
};

enum mouseButton {
    MOUSE_LEFT = 0,
    MOUSE_MIDDLE = 1,
    MOUSE_RIGHT = 2,
    MOUSE_RELEASE = 3,
    MOUSE_WHEEL_UP = 64,
    MOUSE_WHEEL_DOWN = 65,
    MOUSE_DRAG = 32
};

// Syntax Highlighting
#define HL_NORMAL 0
#define HL_COMMENT 1
#define HL_MLCOMMENT 2
#define HL_KEYWORD1 3
#define HL_KEYWORD2 4
#define HL_STRING 5
#define HL_NUMBER 6
#define HL_MATCH 7
#define HL_VISUAL 8

#define HL_HIGHLIGHT_NUMBERS (1<<0)
#define HL_HIGHLIGHT_STRINGS (1<<1)

typedef struct editorSyntax {
    char *filetype;
    char **filematch;
    char **keywords;
    char *singleline_comment_start;
    char *multiline_comment_start;
    char *multiline_comment_end;
    int flags;
} editorSyntax;

// Data Structures
typedef struct erow {
    int size;
    char *chars;
    unsigned char *hl;
    int hl_open_comment;
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
    
    // Selection/Visual Mode
    int sel_sx, sel_sy; // Selection start
    
    // Mouse State
    int mouse_x, mouse_y, mouse_b;
    int is_dragging;

    char *search_pattern;
    int last_match;
    int search_direction;
    editorSyntax *syntax;
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
void editorUpdateSyntax(erow *row);
int editorSyntaxToColor(int hl);
void editorSelectSyntaxHighlight();
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