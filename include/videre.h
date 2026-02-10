#ifndef VIDERE_H
#define VIDERE_H

#include <termios.h>
#include <unistd.h>

typedef struct erow {
    int size;
    char *chars;
} erow;

typedef struct {
    int cx, cy;
    int screenrows;
    int screencols;
    int numrows;
    erow *row;
    struct termios orig_termios;
} EditorConfig;

extern EditorConfig E;

void die(const char *s);
void editorOpen(char *filename);
void editorUpdateRow(erow *row);

#endif
