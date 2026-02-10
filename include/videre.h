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
    MOUSE_EVENT,
    PASTE_EVENT,
    FIND_CHAR,
    FIND_CHAR_BACK,
    TILL_CHAR,
    TILL_CHAR_BACK
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
#define HL_MATCH_CURSOR 9
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
    int idx;
    int size;
    char *chars;
    unsigned char *hl;
    int hl_open_comment;
} erow;

typedef struct {
    char *chars;
    int size;
    int is_line;
} editorRegister;

typedef struct editorUndoState {
    int numrows;
    erow *row;
    int cx, cy;
    struct editorUndoState *next;
} editorUndoState;

typedef struct {
    int cx, cy;
    int preferredColumn;
    int rowoff;
    int coloff;
    int screenrows;
    int screencols;
    int numrows;
    int row_capacity;
    erow *row;
    int dirty;
    char *filename;
    char git_status[64];
    char statusmsg[256];
    time_t statusmsg_time;
    int mode;
    
    // Selection/Visual Mode
    int sel_sx, sel_sy; // Selection start
    
    // Mouse State
    int mouse_x, mouse_y, mouse_b;
    int is_dragging;
    char *paste_buffer;

    char *search_pattern;
    int last_match;
    int search_direction;
    
    // Marks (a-z)
    int mark_x[26];
    int mark_y[26];
    int mark_set[26];

    // Character search state
    char last_search_char;
    int last_search_char_found;
    editorSyntax *syntax;
    
    // Registers
    editorRegister registers[256];
    
    // Undo/Redo
    editorUndoState *undo_stack;
    editorUndoState *redo_stack;

    // Context Menu State
    int menu_open;
    int menu_x, menu_y;
    int menu_selected;

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
void die(const char *s) __attribute__((noreturn));
void editorOpen(char *filename);
void editorUpdateGitStatus();
void editorSave();
void editorFind();
void editorFindNext(int direction);
void editorUpdateRow(erow *row);
void editorUpdateSyntax(erow *row);
int editorSyntaxToColor(int hl);
void editorSelectSyntaxHighlight();
void editorUpdateSearchHighlight();
void editorInsertChar(int c);
void editorInsertNewline();
void editorDelChar();
void editorRowInsertChar(erow *row, int at, int c);
void editorRowDelChar(erow *row, int at);
void editorRowAppendString(erow *row, char *s, size_t len);
void editorFreeRow(erow *row);
void editorDelRow(int at);
void editorInsertRow(int at, char *s, size_t len);

// Yank/Paste
void editorYank(int sx, int sy, int ex, int ey, int is_line);
void editorPaste();
void editorSelectAll();
void editorIncrementNumber(int count);

// Input
int editorHandleMouse();
int editorProcessKeypress();

// Undo/Redo
void editorSaveUndoState();
void editorUndo();
void editorRedo();
void editorFreeUndoState(editorUndoState *state);

// Higher level utils
void editorDeleteRange(int sx, int sy, int ex, int ey);
void editorSelectWord();
void editorSelectAll();
void editorIncrementNumber(int count);
void editorSetMark(int mark);
void editorGoToMark(int mark);
void editorFindChar(char c, int direction);
void editorFindCharTill(char c, int direction);
void editorRepeatCharSearch();
void editorMoveWordForward(int big_word);
void editorMoveWordBackward(int big_word);
void editorMoveWordEnd(int big_word);
void editorMatchBracket();
void editorMoveToLineStart();
void editorMoveToFirstNonWhitespace();
void editorMoveToLineEnd();
void editorMoveToFileStart();
void editorMoveToFileEnd();
void editorGoToLine(int line_num);
void editorMoveToPreviousParagraph();
void editorMoveToNextParagraph();
void editorChangeCase(int to_upper);
void editorIndent(int indent);

void abAppend(struct abuf *ab, const char *s, int len);
void abFree(struct abuf *ab);
void editorSetStatusMessage(const char *fmt, ...);
char *editorPrompt(char *prompt, void (*callback)(char *, int));
void editorRefreshScreen();

#endif