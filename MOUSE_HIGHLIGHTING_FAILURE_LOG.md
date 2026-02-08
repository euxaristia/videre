# Mouse Highlighting Failure Post-Mortem

**Date:** February 8, 2026
**Status:** Unresolved
**Issue:** Mouse click-and-drag text selection (Visual Mode) is not rendering the expected highlighting, behaving differently from standard `nvim`.

## attempted Implementations

1.  **SGR Mouse Protocol Support:**
    *   Enabled mouse tracking with `\u{001B}[?1002h\u{001B}[?1006h`.
    *   Implemented a parser for SGR sequences (`ESC [ < button ; x ; y M/m`) in `readMouseSequence()`.
    *   Mapped Button 32 (Drag) to `handleMouseDrag`.

2.  **Visual Mode Integration:**
    *   Updated `handleMouseClick` to set the cursor position and initialize `isDragging` state.
    *   Updated `handleMouseDrag` to switch `EditorState` to `.visual` mode and update the cursor position dynamically.
    *   Ensured `VisualMode` captures the `startPosition` correctly on the initial click.

3.  **Rendering & Highlighting:**
    *   Implemented `applySelectionHighlighting` in the rendering loop.
    *   Algorithm attempts to overlay `SyntaxColor.visualSelection` (ANSI background color 242) onto the syntax-highlighted line.
    *   **Revision 1:** Added logic to re-apply the background color immediately after any ANSI reset code (`\u{001B}[0m`) is encountered within the selection range, to prevent syntax colors from "clearing" the selection background.

## Symptoms & User Feedback
*   User reports "still absolutely no change" after multiple iterations.
*   This suggests either:
    1.  **Input Failure:** The mouse drag events (code 32) are not being received or parsed correctly, so the editor never actually enters Visual Mode during a drag.
    2.  **Render Failure:** The editor enters Visual Mode, but the ANSI background color codes are being overridden, malformed, or ignored by the terminal.
    3.  **Desynchronization:** The logic mapping raw string indices to highlighted string indices might be failing, causing the background color to be applied to the wrong positions (or nowhere).

## Suspected Causes
1.  **Terminal Compatibility:** The specific terminal emulator in use might handle SGR mouse codes or ANSI color layering differently than tested (e.g., handling background colors on top of syntax colors).
2.  **Event Flooding:** Mouse drag generates a high volume of input events. The current `read` loop might be dropping bytes or misaligning escape sequence parsing under load.
3.  **Color Collision:** `SyntaxHighlighter` resets colors frequently. If the selection highlighting wrapper doesn't perfectly encapsulate the syntax codes, the terminal might default to the syntax background (usually transparent/default) instead of the selection background.

## Future Recommendations
*   **Debug Input:** Log raw byte streams to verify `32;x;yM` sequences are actually reaching the `readMouseSequence` handler.
*   **Simplify Rendering:** Temporarily disable syntax highlighting to verify if selection highlighting works on plain text.
*   **Unit Tests:** Create specific tests for `applySelectionHighlighting` with complex ANSI strings to verify the string manipulation logic.
