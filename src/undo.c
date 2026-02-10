#include "videre.h"
#include <stdlib.h>
#include <string.h>

void editorFreeUndoState(editorUndoState *state) {
    if (!state) return;
    for (int i = 0; i < state->numrows; i++) {
        free(state->row[i].chars);
        free(state->row[i].hl);
    }
    free(state->row);
    free(state);
}

editorUndoState *editorCreateUndoState() {
    editorUndoState *state = malloc(sizeof(editorUndoState));
    state->numrows = E.numrows;
    state->cx = E.cx;
    state->cy = E.cy;
    state->row = malloc(sizeof(erow) * E.numrows);
    for (int i = 0; i < E.numrows; i++) {
        state->row[i].size = E.row[i].size;
        state->row[i].chars = malloc(E.row[i].size + 1);
        memcpy(state->row[i].chars, E.row[i].chars, E.row[i].size + 1);
        state->row[i].hl = malloc(E.row[i].size);
        memcpy(state->row[i].hl, E.row[i].hl, E.row[i].size);
        state->row[i].hl_open_comment = E.row[i].hl_open_comment;
    }
    state->next = NULL;
    return state;
}

void editorSaveUndoState() {
    editorUndoState *state = editorCreateUndoState();
    state->next = E.undo_stack;
    E.undo_stack = state;

    // Clear redo stack on new action
    while (E.redo_stack) {
        editorUndoState *next = E.redo_stack->next;
        editorFreeUndoState(E.redo_stack);
        E.redo_stack = next;
    }
}

void editorApplyUndoState(editorUndoState *state) {
    for (int i = 0; i < E.numrows; i++) editorFreeRow(&E.row[i]);
    free(E.row);

    E.numrows = state->numrows;
    E.row = malloc(sizeof(erow) * E.numrows);
    for (int i = 0; i < E.numrows; i++) {
        E.row[i].size = state->row[i].size;
        E.row[i].chars = malloc(state->row[i].size + 1);
        memcpy(E.row[i].chars, state->row[i].chars, state->row[i].size + 1);
        E.row[i].hl = malloc(state->row[i].size);
        memcpy(E.row[i].hl, state->row[i].hl, state->row[i].size);
        E.row[i].hl_open_comment = state->row[i].hl_open_comment;
    }
    E.cx = state->cx;
    E.cy = state->cy;
    E.dirty++;
}

void editorUndo() {
    if (!E.undo_stack) return;
    
    editorUndoState *redo_state = editorCreateUndoState();
    redo_state->next = E.redo_stack;
    E.redo_stack = redo_state;

    editorUndoState *undo_state = E.undo_stack;
    E.undo_stack = undo_state->next;
    
    editorApplyUndoState(undo_state);
    editorFreeUndoState(undo_state);
    editorSetStatusMessage("Undo");
}

void editorRedo() {
    if (!E.redo_stack) return;

    editorUndoState *undo_state = editorCreateUndoState();
    undo_state->next = E.undo_stack;
    E.undo_stack = undo_state;

    editorUndoState *redo_state = E.redo_stack;
    E.redo_stack = redo_state->next;

    editorApplyUndoState(redo_state);
    editorFreeUndoState(redo_state);
    editorSetStatusMessage("Redo");
}

