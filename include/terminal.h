#ifndef TERMINAL_H
#define TERMINAL_H

void enableRawMode();
void disableRawMode();
int readKey();
int getWindowSize(int *rows, int *cols);

#endif
