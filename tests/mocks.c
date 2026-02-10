#include <stdio.h>
#include "terminal.h"

int getWindowSize(int *rows, int *cols) {
    *rows = 24;
    *cols = 80;
    return 0;
}

int readKey() { return 0; }
void enableRawMode() {}
void disableRawMode() {}

