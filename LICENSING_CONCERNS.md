# Licensing & Derivative Work Analysis for Videre

**Date:** February 8, 2026
**Project:** Videre (Swift-based Text Editor)

## Executive Summary
**Videre is likely NOT a "derivative work" of classic vi or Neovim in the copyright sense.** It is a clean-room reimplementation of the **visual and behavioral specification** (the "look and feel" and keybindings) of vi/vim, written in a completely different programming language (Swift vs. C/Lua).

## Detailed Analysis

### 1. Codebase Origin (Copyright)
*   **Vi/Vim/Neovim:** These projects are primarily written in C (and Lua for Neovim).
*   **Videre:** This project is written entirely in Swift.
*   **Evidence:** A codebase investigation confirms that `videre` uses idiomatic Swift data structures (e.g., `GapBuffer` implementation) and architectural patterns (Struct-based state, Swift Standard Library) that do not exist in the original C codebases.
*   **Conclusion:** There is no evidence of "copy-pasting" source code. Copyright protects the *expression* (the specific code), not the *idea* (a modal text editor). Since the expression is entirely new, it is not a derivative of the source code.

### 2. "Look and Feel" & Functionality (Patents/Trade Dress)
*   **Keybindings (hjkl, etc.):** The specific command set of `vi` is generally considered a standard interface or system of operation, which is typically not copyrightable (reference: *Lotus Dev. Corp. v. Borland Int'l, Inc.*, though jurisdiction varies).
*   **Visual Design:** The "TUI" (Terminal User Interface) layout of vim is a functional standard.
*   **Status:** Many editors (Evil mode in Emacs, VscodeVim, IdeaVim) reimplement these behaviors without legal issue.

### 3. Licensing Compatibility
*   **Videre License:** MIT (Permissive).
*   **Vim License:** Vim License (Charityware, GPL-compatible).
*   **Implication:** Since Videre does not use Vim's code, you are not bound by the Vim License. You are free to license Videre under MIT, Apache, or any other license you choose.

## Recommendation
You can safely state that Videre is a **"modal editor inspired by vi/vim"** rather than a derivative.

*Disclaimer: I am an AI, not a lawyer. This analysis is based on software engineering standards and open-source conventions, not legal counsel.*

---

# Appendix: SwiftDoom & ZigDoom Analysis

**Date:** February 8, 2026
**Context:** User also inquired about two other projects: `~/Projects/SwiftDoom` and `~/Projects/ZigDoom`.

## Analysis Findings

1.  **Project Structure:**
    *   **SwiftDoom:** A native Swift implementation (`Sources/DoomEngine`) using GLFW/OpenGL.
    *   **ZigDoom:** A native Zig implementation (`src/wad.zig`, etc.).
    *   **Reference Material:** Both directories contain a `crispy-doom` subdirectory (a known GPL source port), suggesting it is being used as a reference implementation or for comparison.

2.  **Copyright & "Derivative Work" Status:**
    *   **The "Doom Source" Factor:** Unlike `vi` (which is defined by its behavior), the Doom Engine is defined by its *specific implementation* of complex algorithms (BSP traversal, sector physics, WAD parsing). The original source code was released under the **GPL** in 1999.
    *   **The "Look and Feel" Rule:** If you wrote these engines by strictly reading the *Uncorked* specs (file formats) without looking at the Doom C source code, they *might* be clean-room implementations.
    *   **The Reality:** However, given the complexity of the Doom engine and the presence of `crispy-doom` in the project folders, it is highly likely that the original C code was consulted to ensure accuracy. In the open-source legal world (and specifically the Doom community), if you reference GPL code to write your own, your code is generally considered a **derivative work**.

## Recommendation

**These projects should likely be licensed under the GNU General Public License (GPL).**

*   **Why?**
    *   If you looked at GPL source code to understand *how* to implement a function, your implementation is derivative.
    *   The Doom source port community standard is GPL.
    *   It protects you from legal ambiguity regarding id Software's original copyright on the *code*.

*   **GPLv2 vs GPLv3:**
    *   Original Doom is GPLv2.
    *   If you use code/logic from modern ports (like GZDoom/Crispy Doom), check their licenses (mostly GPLv2+).
    *   **Safe Bet:** **GPLv2 or later**.

## Important Note on Assets (WADs)
*   **The Engine** is (likely) Free Software (GPL).
*   **The Game Data (Doom.wad, Doom2.wad)** is **Proprietary Copyrighted Material** owned by id Software/Bethesda.
*   **DO NOT** commit the official `.wad` files to your Git repositories.
*   **DO** use the shareware `doom1.wad` or `freedoom.wad` for testing/distribution if needed.