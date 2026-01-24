# Quick Start Tutorial

This tutorial will get you editing with Vite in 5 minutes.

## Your First Edit Session

### 1. Open Vite

```sh
vi hello.txt
```

You'll see an empty buffer with faint line numbers and tildes (`~`) indicating empty lines.

### 2. Enter Insert Mode

Press `i` to enter Insert mode. The status bar will show `hello.txt [+]` (indicating unsaved changes).

### 3. Type Some Text

```
Hello, Vite!
This is my first edit.
```

### 4. Return to Normal Mode

Press `ESC` to return to Normal mode.

### 5. Save the File

Type `:w` and press Enter. You'll see a message: `"hello.txt" 2 lines written`

### 6. Quit Vite

Type `:q` and press Enter.

**Congratulations!** You've just completed your first edit session.

## Understanding Modes

Vite has four modes:

### Normal Mode (default)

Navigate and execute commands. Press `ESC` to return here from any mode.

**Common commands:**
- `h` `j` `k` `l` - Move left, down, up, right
- `w` - Next word
- `b` - Previous word
- `0` - Line start
- `$` - Line end

### Insert Mode

Type text like a normal editor. Enter with:
- `i` - Insert before cursor
- `a` - Insert after cursor
- `I` - Insert at line start
- `A` - Insert at line end
- `o` - Open new line below
- `O` - Open new line above

Press `ESC` to return to Normal mode.

### Visual Mode

Select text for operations. Enter with `v` (character-wise) or `V` (line-wise).

*Note: Visual mode is currently implemented but operations are limited.*

### Command Mode

Execute editor commands. Enter with `:` from Normal mode.

**Common commands:**
- `:w` - Save
- `:q` - Quit
- `:wq` - Save and quit
- `:q!` - Quit without saving
- `:e filename` - Open file

## Basic Editing Workflow

### Example 1: Editing a Configuration File

```sh
vi ~/.bashrc
```

1. Navigate to the line you want to edit with `j` and `k`
2. Press `A` to append at end of line
3. Type your changes
4. Press `ESC` to return to Normal mode
5. Type `:wq` to save and quit

### Example 2: Deleting Text

Open a file:
```sh
vi myfile.txt
```

**Delete a word:**
1. Move cursor to the word
2. Type `dw` (delete word)

**Delete a line:**
1. Type `dd` (delete entire line)

**Delete to end of line:**
1. Type `d$` (delete from cursor to end)

### Example 3: Copy and Paste

**Copy (yank) a line:**
1. Position cursor on the line
2. Type `yy` (yank line)

**Paste:**
1. Move cursor where you want to paste
2. Type `p` (paste after cursor) or `P` (paste before cursor)

### Example 4: Moving Around

**Jump to line 10:**
```
:10
```

**Go to top of file:**
```
gg
```

**Go to bottom of file:**
```
G
```

**Find character 'x' on current line:**
```
fx
```

## Count Prefixes

Many commands accept numeric prefixes for repetition:

- `3j` - Move down 3 lines
- `5w` - Move forward 5 words
- `2dd` - Delete 2 lines
- `3yy` - Yank 3 lines

## Common Patterns

### Search and Replace a Word

1. Move to the word
2. Type `ciw` (change inner word)
3. Type the replacement text
4. Press `ESC`

### Delete Everything After Cursor

```
dG
```

### Insert at Multiple Lines

1. Type `o` to open a new line
2. Type your text
3. Press `ESC`
4. Type `.` to repeat on the next line

*(Note: `.` repeat command is not yet implemented but is on the roadmap)*

## Getting Help

**While editing:**
- Press `ESC` to return to Normal mode if you're lost
- Type `:q!` to quit without saving

**Documentation:**
- [Keybindings Reference](Keybindings)
- [Command Reference](Commands)
- [Modal Editing Guide](Modal-Editing)

## Next Steps

- Learn more [Motions](Motions) for faster navigation
- Master [Operators](Operators) for powerful editing
- Explore [Advanced Keybindings](Keybindings)
