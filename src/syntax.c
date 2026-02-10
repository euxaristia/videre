#include "videre.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

char *C_HL_extensions[] = { ".c", ".h", ".cpp", NULL };
char *C_HL_keywords[] = {
  "switch", "if", "while", "for", "break", "continue", "return", "else",
  "struct", "union", "typedef", "static", "enum", "class", "case",
  "int|", "long|", "double|", "float|", "char|", "unsigned|", "signed|",
  "void|", NULL
};

char *SWIFT_HL_extensions[] = { ".swift", NULL };
char *SWIFT_HL_keywords[] = {
  "if", "else", "for", "while", "do", "switch", "case", "default", "break",
  "continue", "return", "func", "var", "let", "class", "struct", "enum",
  "extension", "protocol", "init", "deinit", "subscript", "typealias",
  "import", "public", "private", "internal", "fileprivate", "open",
  "override", "final", "static", "mutating", "nonmutating", "indirect",
  "Int|", "Float|", "Double|", "Bool|", "String|", "Character|", "UInt|", NULL
};

editorSyntax HLDB[] = {
  {
    "c",
    C_HL_extensions,
    C_HL_keywords,
    "//", "/*", "*/",
    HL_HIGHLIGHT_NUMBERS | HL_HIGHLIGHT_STRINGS
  },
  {
    "swift",
    SWIFT_HL_extensions,
    SWIFT_HL_keywords,
    "//", "/*", "*/",
    HL_HIGHLIGHT_NUMBERS | HL_HIGHLIGHT_STRINGS
  }
};

#define HLDB_ENTRIES (sizeof(HLDB) / sizeof(HLDB[0]))

int is_separator(int c) {
  return isspace(c) || c == '\0' || strchr(",.()+-/*=~%<>[];", c) != NULL;
}

void editorUpdateSyntax(erow *row) {
  if (row->size < 0) return;
  unsigned char *new_hl = realloc(row->hl, row->size);
  if (!new_hl && row->size > 0) die("realloc hl");
  row->hl = new_hl;
  
  if (row->size > 0) memset(row->hl, HL_NORMAL, row->size);

  if (E.syntax == NULL) return;

  char **keywords = E.syntax->keywords;
  char *scs = E.syntax->singleline_comment_start;
  char *mcs = E.syntax->multiline_comment_start;
  char *mce = E.syntax->multiline_comment_end;

  int scs_len = scs ? strlen(scs) : 0;
  int mcs_len = mcs ? strlen(mcs) : 0;
  int mce_len = mce ? strlen(mce) : 0;

  int prev_sep = 1;
  int in_string = 0;
  
  int filerow = row->idx;
  int in_comment = (filerow > 0 && E.row[filerow - 1].hl_open_comment);

  int i = 0;
  while (i < row->size) {
    char c = row->chars[i];

    // Single-line comments
    if (scs_len && !in_string && !in_comment) {
      if (i + scs_len <= row->size && !strncmp(&row->chars[i], scs, scs_len)) {
        memset(&row->hl[i], HL_COMMENT, row->size - i);
        break;
      }
    }

    // Multi-line comments
    if (mcs_len && mce_len && !in_string) {
      if (in_comment) {
        row->hl[i] = HL_MLCOMMENT;
        if (i + mce_len <= row->size && !strncmp(&row->chars[i], mce, mce_len)) {
          memset(&row->hl[i], HL_MLCOMMENT, mce_len);
          i += mce_len;
          in_comment = 0;
          prev_sep = 1;
          continue;
        } else {
          i++;
          continue;
        }
      } else if (i + mcs_len <= row->size && !strncmp(&row->chars[i], mcs, mcs_len)) {
        memset(&row->hl[i], HL_MLCOMMENT, mcs_len);
        i += mcs_len;
        in_comment = 1;
        continue;
      }
    }

    // Strings
    if (E.syntax->flags & HL_HIGHLIGHT_STRINGS) {
      if (in_string) {
        row->hl[i] = HL_STRING;
        if (c == '\\' && i + 1 < row->size) {
          row->hl[i + 1] = HL_STRING;
          i += 2;
          continue;
        }
        if (c == in_string) in_string = 0;
        i++;
        prev_sep = 1;
        continue;
      } else {
        if (c == '\'' || c == '"') {
          in_string = c;
          row->hl[i] = HL_STRING;
          i++;
          continue;
        }
      }
    }

    // Numbers
    if (E.syntax->flags & HL_HIGHLIGHT_NUMBERS) {
      if ((isdigit(c) && prev_sep) ||
          (c == '.' && prev_sep && i + 1 < row->size && isdigit(row->chars[i + 1]))) {
        int j = i;
        if (isdigit(c)) {
          while (j < row->size && (isdigit(row->chars[j]) || row->chars[j] == '.')) j++;
        }
        if (j > i) {
          memset(&row->hl[i], HL_NUMBER, j - i);
          i = j;
          prev_sep = 0;
          continue;
        }
      }
    }

    // Keywords
    if (prev_sep) {
      int j;
      for (j = 0; keywords[j]; j++) {
        int klen = strlen(keywords[j]);
        int kw2 = keywords[j][klen - 1] == '|';
        if (kw2) klen--;

        if (i + klen <= row->size && !strncmp(&row->chars[i], keywords[j], klen)) {
            if (i + klen == row->size || is_separator(row->chars[i + klen])) {
                memset(&row->hl[i], kw2 ? HL_KEYWORD2 : HL_KEYWORD1, klen);
                i += klen;
                break;
            }
        }
      }
      if (keywords[j]) {
        prev_sep = 0;
        continue;
      }
    }

    prev_sep = is_separator(c);
    i++;
  }

  row->hl_open_comment = in_comment;
}

int editorSyntaxToColor(int hl) {
  switch (hl) {
    case HL_COMMENT:
    case HL_MLCOMMENT: return 32; // Green
    case HL_KEYWORD1: return 33; // Yellow
    case HL_KEYWORD2: return 36; // Cyan
    case HL_STRING: return 35; // Magenta
    case HL_NUMBER: return 31; // Red
    case HL_MATCH: return 34; // Blue (dim)
    case HL_MATCH_CURSOR: return 33; // Yellow (bright - current match)
    case HL_VISUAL: return 38; // Grey
    default: return 37; // White
  }
}

void editorUpdateSearchHighlight() {
  for (int filerow = 0; filerow < E.numrows; filerow++) {
    editorUpdateSyntax(&E.row[filerow]);
  }

  if (E.search_pattern == NULL || strlen(E.search_pattern) == 0) return;
  
  int qlen = strlen(E.search_pattern);
  
  for (int filerow = 0; filerow < E.numrows; filerow++) {
    erow *row = &E.row[filerow];
    char *match = row->chars;
    
    while ((match = strstr(match, E.search_pattern)) != NULL) {
      int match_col = match - row->chars;
      
      // Check if this is the current cursor position (bright highlight)
      if (filerow == E.cy && match_col <= E.cx && E.cx < match_col + qlen) {
        for (int i = 0; i < qlen; i++) {
          row->hl[match_col + i] = HL_MATCH_CURSOR;
        }
      } else {
        for (int i = 0; i < qlen; i++) {
          row->hl[match_col + i] = HL_MATCH;
        }
      }
      match++;
    }
  }
}

void editorSelectSyntaxHighlight() {
  E.syntax = NULL;
  if (E.filename == NULL) return;

  char *ext = strrchr(E.filename, '.');

  for (unsigned int j = 0; j < HLDB_ENTRIES; j++) {
    editorSyntax *s = &HLDB[j];
    unsigned int i = 0;
    while (s->filematch[i]) {
      int is_ext = (s->filematch[i][0] == '.');
      if ((is_ext && ext && !strcmp(ext, s->filematch[i])) ||
          (!is_ext && strstr(E.filename, s->filematch[i]))) {
        E.syntax = s;

        int filerow;
        for (filerow = 0; filerow < E.numrows; filerow++) {
          editorUpdateSyntax(&E.row[filerow]);
        }
        return;
      }
      i++;
    }
  }
}
