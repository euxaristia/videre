#ifndef TEXT_OBJECT_ENGINE_H
#define TEXT_OBJECT_ENGINE_H

#include "videre.h"

// Text object types
typedef enum {
    TEXT_OBJECT_WORD,      // iw, aw
    TEXT_OBJECT_QUOTE,      // i", a", i', a'
    TEXT_OBJECT_BRACKET,    // i(, a(, i[, a[, i{, a{
    TEXT_OBJECT_PARAGRAPH,  // ip, ap
} TextObjectType;

// Text object range
typedef struct {
    int start_y, start_x;  // Start position
    int end_y, end_x;       // End position
    int valid;              // Is the range valid?
} TextObjectRange;

// Word character detection
static inline int is_word_char(char c) {
    return (c >= 'a' && c <= 'z') || 
           (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9') || 
           c == '_';
}

// Whitespace detection
static inline int is_whitespace_char(char c) {
    return c == ' ' || c == '\t' || c == '\n';
}

// Get matching bracket for a bracket character
static inline char get_matching_bracket(char c) {
    switch (c) {
        case '(': return ')';
        case ')': return '(';
        case '[': return ']';
        case ']': return '[';
        case '{': return '}';
        case '}': return '{';
        case '<': return '>';
        case '>': return '<';
        default: return c;
    }
}

// Is this a bracket character?
static inline int is_bracket_char(char c) {
    return c == '(' || c == ')' || 
           c == '[' || c == ']' || 
           c == '{' || c == '}' ||
           c == '<' || c == '>';
}

// Text Object Engine
typedef struct {
    EditorConfig *E;
} TextObjectEngine;

void text_object_engine_init(TextObjectEngine *engine, EditorConfig *editor) {
    engine->E = editor;
}

// Inner word (iw) - word under cursor, no surrounding whitespace
TextObjectRange text_object_inner_word(TextObjectEngine *engine) {
    TextObjectRange range = {0, 0, 0, 0, 0};
    
    if (!engine->E || engine->E->numrows == 0) return range;
    
    int cy = engine->E->cy;
    int cx = engine->E->cx;
    erow *row = &engine->E->row[cy];
    
    if (cx >= row->size) {
        cx = row->size > 0 ? row->size - 1 : 0;
    }
    
    // Find word start
    int start = cx;
    while (start > 0 && is_word_char(row->chars[start - 1])) {
        start--;
    }
    
    // Find word end
    int end = cx;
    while (end < row->size && is_word_char(row->chars[end])) {
        end++;
    }
    
    range.start_y = cy;
    range.start_x = start;
    range.end_y = cy;
    range.end_x = end;
    range.valid = 1;
    
    return range;
}

// A word (aw) - word plus trailing whitespace
TextObjectRange text_object_a_word(TextObjectEngine *engine) {
    TextObjectRange range = text_object_inner_word(engine);
    
    if (!range.valid) return range;
    
    erow *row = &engine->E->row[range.end_y];
    
    // Include trailing whitespace
    while (range.end_x < row->size && is_whitespace_char(row->chars[range.end_x])) {
        range.end_x++;
    }
    
    return range;
}

// Inner quotes (i" or i') - content between quotes, excluding quotes
TextObjectRange text_object_inner_quote(TextObjectEngine *engine, char quote) {
    TextObjectRange range = {0, 0, 0, 0, 0};
    
    if (!engine->E || engine->E->numrows == 0) return range;
    
    int cy = engine->E->cy;
    int cx = engine->E->cx;
    erow *row = &engine->E->row[cy];
    
    if (cx >= row->size) cx = row->size - 1;
    
    int open = -1, close = -1;
    
    // Check if cursor is on a quote
    if (row->chars[cx] == quote) {
        // Could be opening or closing, search both directions
        int found_prev = 0;
        for (int i = cx - 1; i >= 0; i--) {
            if (row->chars[i] == quote) {
                found_prev = 1;
                break;
            }
        }
        if (found_prev) {
            close = cx;  // It's a closing quote
        } else {
            open = cx;  // It's an opening quote
        }
    }
    
    // Find opening quote
    if (open == -1) {
        for (int i = cx; i >= 0; i--) {
            if (row->chars[i] == quote) {
                open = i;
                break;
            }
        }
    }
    
    // Find closing quote
    if (close == -1) {
        int search_start = (open >= 0) ? open + 1 : cx;
        for (int i = search_start; i < row->size; i++) {
            if (row->chars[i] == quote) {
                close = i;
                break;
            }
        }
    }
    
    // Valid if we found both and opening is before closing
    if (open >= 0 && close >= 0 && open < close) {
        range.start_y = cy;
        range.start_x = open + 1;  // Exclude opening quote
        range.end_y = cy;
        range.end_x = close;      // Include up to but not including closing quote
        range.valid = 1;
    }
    
    return range;
}

// A quotes (a" or a') - content between quotes, including quotes
TextObjectRange text_object_a_quote(TextObjectEngine *engine, char quote) {
    TextObjectRange range = text_object_inner_quote(engine, quote);
    
    if (!range.valid) return range;
    
    // Expand to include the quotes themselves
    range.start_x--;
    range.end_x++;
    
    return range;
}

// Inner brackets (i(, i[, i{) - content between brackets, excluding brackets
TextObjectRange text_object_inner_bracket(TextObjectEngine *engine, char open_bracket) {
    TextObjectRange range = {0, 0, 0, 0, 0};
    
    if (!engine->E || engine->E->numrows == 0) return range;
    
    int cy = engine->E->cy;
    int cx = engine->E->cx;
    erow *row = &engine->E->row[cy];
    char close_bracket = get_matching_bracket(open_bracket);
    
    if (cx >= row->size) cx = row->size - 1;
    
    int depth = 0;
    int open = -1, close = -1;
    
    // Search backward for opening bracket
    for (int i = cx; i >= 0; i--) {
        if (row->chars[i] == close_bracket) {
            depth++;
        } else if (row->chars[i] == open_bracket) {
            if (depth == 0) {
                open = i;
                break;
            } else {
                depth--;
            }
        }
    }
    
    // Search forward for closing bracket
    depth = 0;
    int search_start = (open >= 0) ? open + 1 : cx;
    for (int i = search_start; i < row->size; i++) {
        if (row->chars[i] == open_bracket) {
            depth++;
        } else if (row->chars[i] == close_bracket) {
            if (depth == 0) {
                close = i;
                break;
            } else {
                depth--;
            }
        }
    }
    
    if (open >= 0 && close >= 0 && open < close) {
        range.start_y = cy;
        range.start_x = open + 1;  // Exclude opening bracket
        range.end_y = cy;
        range.end_x = close;        // Include up to but not including closing bracket
        range.valid = 1;
    }
    
    return range;
}

// A brackets (a(, a[, a{) - content between brackets, including brackets
TextObjectRange text_object_a_bracket(TextObjectEngine *engine, char open_bracket) {
    TextObjectRange range = text_object_inner_bracket(engine, open_bracket);
    
    if (!range.valid) return range;
    
    // Expand to include the brackets themselves
    range.start_x--;
    range.end_x++;
    
    return range;
}

// Apply text object motion
void text_object_apply_motion(TextObjectEngine *engine, TextObjectType type, char quote_or_bracket) {
    TextObjectRange range = {0, 0, 0, 0, 0};
    
    switch (type) {
        case TEXT_OBJECT_WORD:
            range = text_object_inner_word(engine);
            break;
        case TEXT_OBJECT_QUOTE:
            range = text_object_inner_quote(engine, quote_or_bracket);
            break;
        case TEXT_OBJECT_BRACKET:
            range = text_object_inner_bracket(engine, quote_or_bracket);
            break;
        default:
            return;
    }
    
    if (range.valid) {
        engine->E->sel_sy = range.start_y;
        engine->E->sel_sx = range.start_x;
        engine->E->cy = range.end_y;
        engine->E->cx = range.end_x;
        engine->E->mode = MODE_VISUAL;
    }
}

#endif // TEXT_OBJECT_ENGINE_H
