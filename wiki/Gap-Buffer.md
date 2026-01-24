# Gap Buffer Architecture

Vite uses a **gap buffer** for text storage—a classic data structure that provides O(1) insertions and deletions at the cursor position.

## What is a Gap Buffer?

A gap buffer is an array with an efficient "gap" (empty space) maintained at the current edit location. As you type, characters fill the gap. When you move the cursor, the gap relocates.

### Visual Example

**Initial state** (empty buffer):

```
[____________________]  ← gap
 ^cursor
```

**After typing "Hello"**:

```
[Hello______________]
      ^cursor (gap follows)
```

**After moving cursor to start and typing "X"**:

```
[XHello_____________]
  ^cursor
```

**After moving cursor to middle (between 'l' and 'o') and typing "!"**:

```
[XHel!lo____________]
      ^cursor
```

## How It Works

### Internal Representation

The buffer is split into three conceptual regions:

```
┌─────────┬──────────┬─────────┐
│ Before  │   Gap    │  After  │
│  Gap    │ (empty)  │   Gap   │
└─────────┴──────────┴─────────┘
    ↑          ↑          ↑
  0 to      gapStart   gapEnd
gapStart-1             to end
```

**Example with "Hello world"** and cursor between "o" and " ":

```
Text: "Hello world"
Cursor: after 'o'

Array: ['H','e','l','l','o', _, _, _, ' ','w','o','r','l','d']
                               ↑       ↑
                           gapStart  gapEnd
```

### Core Operations

#### 1. Insert Character

**Algorithm:**
1. If gap is empty, expand the array
2. Place character at `gapStart`
3. Increment `gapStart`

**Complexity:** O(1) amortized

**Example:**

```
Before: [H,e,l,l,o,_,_,_, ,w,o,r,l,d]
                   ↑
Insert '!': [H,e,l,l,o,!,_,_, ,w,o,r,l,d]
                     ↑
```

#### 2. Delete Character

**Algorithm:**
1. Decrement `gapStart` (backspace)
2. Or increment `gapEnd` (delete forward)

**Complexity:** O(1)

**Example (backspace):**

```
Before: [H,e,l,l,o,_,_,_, ,w,o,r,l,d]
                   ↑
After:  [H,e,l,l,_,_,_,_, ,w,o,r,l,d]
                 ↑
```

#### 3. Move Cursor

**Algorithm:**
1. Move characters from one side of gap to the other
2. Update `gapStart` and `gapEnd`

**Complexity:** O(distance moved)

**Example** (move cursor right by 2):

```
Before: [H,e,l,l,o,_,_,_, ,w,o,r,l,d]
                   ↑
Step 1: Move ' ' to before gap
        [H,e,l,l,o, ,_,_,_,w,o,r,l,d]

Step 2: Move 'w' to before gap
        [H,e,l,l,o, ,w,_,_,o,r,l,d]
                       ↑
```

### Gap Management

**When does the gap grow?**
- When `gapStart == gapEnd` (gap is full)
- Growth strategy: double the gap size

**What's the gap size?**
- Initially: 128 characters
- After growth: previous size × 2
- Max practical gap: limited by available memory

**Can the gap shrink?**
- Not in current implementation
- Future optimization: shrink on large deletions

## Implementation in Vite

### GapBuffer Class

Located in `Core/TextBuffer/GapBuffer.swift`:

```swift
class GapBuffer {
    private var buffer: [Character]
    private var gapStart: Int
    private var gapEnd: Int

    init() {
        buffer = Array(repeating: " ", count: 128)
        gapStart = 0
        gapEnd = 128
    }

    func insert(_ char: Character) {
        if gapStart == gapEnd {
            expandGap()
        }
        buffer[gapStart] = char
        gapStart += 1
    }

    func delete() {
        if gapStart > 0 {
            gapStart -= 1
        }
    }

    func moveCursor(to position: Int) {
        // Relocate gap to new position
        // ...
    }
}
```

### TextBuffer Wrapper

Located in `Core/TextBuffer/TextBuffer.swift`:

```swift
class TextBuffer {
    private var gapBuffer: GapBuffer

    // High-level operations
    func insertCharacter(_ char: Character, at pos: Position)
    func deleteCharacter(at pos: Position)
    func line(_ index: Int) -> String
}
```

**Why the wrapper?**
- Provides line-oriented API on top of character buffer
- Handles newline-delimited access
- Manages position-to-offset translation

## Advantages of Gap Buffers

### ✅ Pros

1. **Fast Sequential Insertion**: O(1) when typing normally
2. **Simple Implementation**: Easier than rope or piece table
3. **Memory Efficient**: No fragmentation, single allocation
4. **Cache Friendly**: Contiguous memory access
5. **Fast Line Access**: No tree traversal needed

### ❌ Cons

1. **Slow Random Access**: Moving gap costs O(n)
2. **Wasted Space**: Gap size adds memory overhead
3. **Large File Performance**: Full copy on gap expansion
4. **Multi-Cursor**: Difficult to optimize (only one gap)

## Comparison to Alternatives

| Data Structure | Insert | Delete | Random Access | Memory | Use Case |
|----------------|--------|--------|---------------|--------|----------|
| **Gap Buffer** | O(1)* | O(1)* | O(n) | Good | Sequential editing |
| **Array** | O(n) | O(n) | O(1) | Excellent | Read-only text |
| **Rope** | O(log n) | O(log n) | O(log n) | Fair | Large files |
| **Piece Table** | O(1) | O(1) | O(n) | Excellent | Undo/redo |

\* Amortized for insertions; best case for deletions

### When Gap Buffer Excels

- **Text editors** (Vi, Emacs)
- **Sequential typing** patterns
- **Small to medium files** (< 10 MB)
- **Single cursor** editing

### When to Use Alternatives

- **Rope**: Multi-gigabyte files, many random edits
- **Piece Table**: Complex undo/redo, change tracking
- **Array**: Static text, no modifications

## Performance Characteristics

### Real-World Scenarios

**Scenario 1: Typing a paragraph**
- Cursor moves forward sequentially
- Gap follows cursor naturally
- **Performance: Excellent** (pure O(1) inserts)

**Scenario 2: Jumping between sections**
- User presses `gg` (top), `G` (bottom), `50G` (line 50)
- Each jump relocates gap
- **Performance: Good** (O(n) relocation, infrequent)

**Scenario 3: Search and replace**
- Find next match: O(n) search
- Delete match: O(1) (gap already at position)
- Insert replacement: O(1)
- **Performance: Good** (search dominates)

**Scenario 4: Delete 1000 lines**
- Gap relocated to start of deletion: O(n)
- Deletion: O(1) (adjust gapEnd)
- **Performance: Excellent**

### Memory Usage

**Example: 1 KB text file**
- Content: 1,024 characters
- Gap: 128 characters (initial)
- Total: 1,152 characters (~1.125× overhead)

**Example: 100 KB text file after heavy editing**
- Content: 102,400 characters
- Gap: 2,048 characters (grown via doubling)
- Total: 104,448 characters (~1.02× overhead)

**Worst case:**
- Gap grows to match content size
- Overhead: 2× (rarely happens)

## Optimizations in Vite

### 1. Lazy Gap Relocation

Gap only moves when needed:
- Insertion at cursor: no relocation
- Cursor motion: relocate on next edit

### 2. Minimal Expansion

Gap size doubles only when completely full.

### 3. Line Caching (Future)

Cache newline positions to speed up line-oriented operations.

### 4. Copy-on-Write (Planned)

Share buffer across undo states, copy only on modification.

## Debugging Gap Buffers

### Visualizing State

Add debug printing:

```swift
extension GapBuffer {
    func debug() {
        print("Buffer: \(buffer)")
        print("Gap: \(gapStart)...\(gapEnd)")
        print("Content: \(content())")
    }
}
```

### Common Bugs

**Bug: Text corruption after cursor movement**
- **Cause**: Incorrect gap relocation logic
- **Fix**: Ensure `gapStart` and `gapEnd` updated atomically

**Bug: Insertion at wrong position**
- **Cause**: Cursor position not synchronized with gap
- **Fix**: Always relocate gap before insertion

**Bug: Out-of-bounds access**
- **Cause**: `gapStart > buffer.count`
- **Fix**: Check bounds in `insert()` and `delete()`

## Further Reading

- [Emacs Buffer Implementation](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-Gap.html)
- [Text Editor Data Structures (2017)](https://cdacamar.github.io/data%20structures/algorithms/benchmarking/text%20editors/c++/editor-data-structures/)
- [Craft of Text Editing](http://www.finseth.com/craft/)

## Related Documentation

- [Architecture Overview](Architecture)
- [TextBuffer API](API-TextBuffer)
- [Performance Optimization](Performance)
