#include "videre.h"
#include <stdlib.h>
#include <string.h>

void editorFreeUndoState(editorUndoState *state) {
    if (!state) return;
    if (!state->row) {
        free(state);
        return;
    }
    for (int i = 0; i < state->numrows; i++) {
        free(state->row[i].chars);
        free(state->row[i].hl);
    }
    free(state->row);
    free(state);
}

editorUndoState *editorCreateUndoState() {
    editorUndoState *state = malloc(sizeof(editorUndoState));
    if (!state) return NULL;
    
    state->numrows = E.numrows;
    state->cx = E.cx;
    state->cy = E.cy;
    
    if (E.numrows > 0) {
        if (!E.row) {
            free(state);
            return NULL;
        }
        // Prevent integer overflow
        if (E.numrows > 1000000) { // Same limit as in rows.c
            free(state);
            return NULL;
        }
        state->row = malloc(sizeof(erow) * E.numrows);
        if (!state->row) {
            free(state);
            return NULL;
        }
        
        for (int i = 0; i < E.numrows; i++) {
            state->row[i].size = E.row[i].size;
            state->row[i].chars = malloc(E.row[i].size + 1);
            if (!state->row[i].chars) {
                // Cleanup
                for (int j = 0; j < i; j++) {
                    free(state->row[j].chars);
                    free(state->row[j].hl);
                }
                free(state->row);
                free(state);
                return NULL;
            }
            memcpy(state->row[i].chars, E.row[i].chars, E.row[i].size + 1);
            
            if (E.row[i].hl) {
                state->row[i].hl = malloc(E.row[i].size);
                if (!state->row[i].hl) {
                    // Non-fatal, just skip hl for this row or cleanup?
                    // For security, let's be consistent
                    free(state->row[i].chars);
                    for (int j = 0; j < i; j++) {
                        free(state->row[j].chars);
                        free(state->row[j].hl);
                    }
                    free(state->row);
                    free(state);
                    return NULL;
                }
                memcpy(state->row[i].hl, E.row[i].hl, E.row[i].size);
            } else {
                state->row[i].hl = NULL;
            }
            state->row[i].hl_open_comment = E.row[i].hl_open_comment;
        }
    } else {
        state->row = NULL;
    }
    
    state->next = NULL;
    return state;
}

void editorSaveUndoState() {
    editorUndoState *state = editorCreateUndoState();
    if (!state) return;
    
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
    // Free existing rows safely
    if (E.row) {
        for (int i = 0; i < E.numrows; i++) editorFreeRow(&E.row[i]);
        free(E.row);
        E.row = NULL; // Prevent use-after-free
    }

    E.numrows = state->numrows;
    if (E.numrows > 0) {
        E.row = malloc(sizeof(erow) * E.numrows);
        if (!E.row) {
            E.numrows = 0;
            die("malloc failed in undo");
            return;
        }
        
        for (int i = 0; i < E.numrows; i++) {
            E.row[i].size = state->row[i].size;
            E.row[i].chars = malloc(state->row[i].size + 1);
            if (!E.row[i].chars) {
                // Cleanup on failure
                for (int j = 0; j < i; j++) {
                    free(E.row[j].chars);
                    free(E.row[j].hl);
                }
                free(E.row);
                E.row = NULL;
                E.numrows = 0;
                die("malloc failed in undo row");
                return;
            }
            memcpy(E.row[i].chars, state->row[i].chars, state->row[i].size + 1);
            
            // Copy syntax highlighting if present
            if (state->row[i].hl) {
                E.row[i].hl = malloc(state->row[i].size);
                if (!E.row[i].hl) {
                    free(E.row[i].chars);
                    E.row[i].chars = NULL;
                    E.row[i].size = 0;
                    continue; // Skip this row but continue with others
                }
                memcpy(E.row[i].hl, state->row[i].hl, state->row[i].size);
            } else {
                E.row[i].hl = NULL;
            }
            E.row[i].hl_open_comment = state->row[i].hl_open_comment;
        }
    } else {
        E.row = NULL;
    }
    
    E.cx = state->cx;
    E.cy = state->cy;
    E.dirty++;
}

void editorUndo() {
    if (!E.undo_stack) return;
    
    editorUndoState *redo_state = editorCreateUndoState();
    if (!redo_state) return;
    redo_state->next = E.redo_stack;
    E.redo_stack = redo_state;

    editorUndoState *undo_state = E.undo_stack;
    E.undo_stack = undo_state->next;
    
    editorApplyUndoState(undo_state);
    editorFreeUndoState(undo_state);
}

void editorRedo() {
    if (!E.redo_stack) return;

    editorUndoState *undo_state = editorCreateUndoState();
    if (!undo_state) return;
    undo_state->next = E.undo_stack;
    E.undo_stack = undo_state;

    editorUndoState *redo_state = E.redo_stack;
    E.redo_stack = redo_state->next;

    editorApplyUndoState(redo_state);
    editorFreeUndoState(redo_state);
}
