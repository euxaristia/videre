# Missing Features from Swift Version - Porting Plan

Based on analysis of the Swift implementation, here are the key features missing from the C version, organized by priority:

## 🔴 HIGH PRIORITY - Core Vi Features

### 1. Text Objects (iw, aw, i", a", i(, a(, etc.)
**Swift Implementation:** `TextObjectEngine.swift` (220 lines)
**Missing in C:** No text object support
**Impact:** Major - fundamental Vi feature for text manipulation
**Porting Effort:** High - requires new engine component

### 2. Character Search Motions (f, F, t, T, ;, ,)
**Swift Implementation:** `MotionEngine.swift` lines 414-483
**Status:** ✅ Implemented in Go version
**Impact:** High - essential for precise navigation

### 3. Advanced Word Motions (w, b, e, W, B, E)
**Swift Implementation:** `MotionEngine.swift` lines 35-281
**C Implementation:** Basic arrow keys only
**Impact:** High - core Vi navigation missing
**Porting Effort:** Medium - extend existing cursor movement

### 4. Bracket Matching
**Swift Implementation:** `MotionEngine.swift` lines 485-538
**Status:** ✅ Implemented in Go version (including forward search)
**Impact:** Medium - important for code navigation

### 5. Advanced Operators (gu, gU, >, <)
**Swift Implementation:** `OperatorEngine.swift`
**Status:** ⚠️ Partial - `>` and `<` implemented for lines and visual selection. `gu`/`gU` missing.
**Impact:** Medium - useful for text manipulation
**Porting Effort:** Medium - requires new operator system

## 🟠 MEDIUM PRIORITY - UI/UX Enhancements

### 6. Search Highlighting
**Swift Implementation:** Highlights all search matches
**Status:** ✅ Implemented in Go version
**Impact:** Medium - better visual feedback

### 7. Enhanced Status Bar
**Swift Features:** Git integration, file info, position indicator
**C Implementation:** Basic filename and cursor position
**Impact:** Low - nice to have but not essential
**Porting Effort:** Low - extend existing status bar

### 8. Mouse Support for Selection
**Swift Implementation:** Full mouse support including drag selection
**Missing in C:** Basic mouse events only
**Impact:** Low - optional feature
**Porting Effort:** High - requires significant mouse handling work

### 9. Context Menu
**Swift Implementation:** Right-click context menu
**Missing in C:** No context menu
**Impact:** Low - convenience feature
**Porting Effort:** High - complex UI work

## 🟡 LOW PRIORITY - Advanced Features

### 10. Mark System (m, ', `)
**Swift Implementation:** Mark system for navigation
**Missing in C:** No mark support
**Impact:** Low - advanced navigation feature
**Porting Effort:** Medium - requires mark storage

### 11. Register System
**Swift Implementation:** Comprehensive register support
**Missing in C:** Basic y/p only
**Impact:** Low - advanced editing feature
**Porting Effort:** High - requires register system

### 12. Enhanced Syntax Highlighting
**Swift Features:** Markdown, HTML, comprehensive language support
**C Implementation:** Basic syntax highlighting
**Impact:** Low - visual improvement
**Porting Effort:** Medium - extend existing syntax system

### 13. Unicode Width Handling
**Swift Implementation:** Sophisticated Unicode display width calculation
**Missing in C:** Basic Unicode support
**Impact:** Low - important for CJK/emoji users
**Porting Effort:** Medium - requires Unicode width tables

## 📋 RECOMMENDED PORTING ORDER

### Phase 1: Core Vi Features (Essential)
1. **Character Search Motions** (f, F, t, T) - Medium effort, high impact
2. **Advanced Word Motions** (w, b, e, W, B, E) - Medium effort, high impact
3. **Text Objects** (iw, aw, i", a") - High effort, essential feature

### Phase 2: Quality of Life (Nice to have)
4. **Bracket Matching** - Low effort, medium impact
5. **Search Highlighting** - Medium effort, medium impact
6. **Advanced Operators** (gu, gU, >, <) - Medium effort, medium impact

### Phase 3: Advanced Features (Optional)
7. **Enhanced Status Bar** - Low effort, low impact
8. **Mark System** - Medium effort, low impact
9. **Mouse Selection** - High effort, low impact

## 🔧 TECHNICAL CONSIDERATIONS

### Architecture Changes Needed:
- **Text Object Engine:** New component for text object calculations
- **Enhanced Motion System:** Extend existing cursor movement
- **Operator System:** New system for complex operators
- **Register System:** New storage for named registers
- **Mark System:** New storage for position marks

### Integration Points:
- **Input Handling:** Extend `editorProcessKeypress()` in `main.c`
- **Cursor Movement:** Modify `editorMoveCursor()` in `core.c`
- **Text Operations:** Extend functions in `edit.c` and `rows.c`
- **Display:** Update syntax highlighting and status bar

### Performance Considerations:
- **Unicode Width:** Use lookup tables for performance (Swift approach)
- **Text Objects:** Cache calculations for better performance
- **Search Highlighting:** Incremental updates to avoid full re-highlight

## 🎯 IMMEDIATE NEXT STEPS

1. **Add Advanced Word Motions** - (w, b, e, W, B, E) - Extend existing movement system
2. **Implement named registers** - Beyond basic yank/paste
3. **Plan Text Object Engine** - Design the architecture for this major feature

This plan prioritizes the most impactful Vi features while considering the technical effort required for each implementation.