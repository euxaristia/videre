import Foundation

/// A gap buffer for efficient text editing
/// The gap represents unallocated space where insertions happen
/// This provides O(1) insertions at the current position
struct GapBuffer {
    private var buffer: [Character]
    private var gapStart: Int
    private var gapEnd: Int

    let minCapacity: Int = 256

    init() {
        buffer = Array(repeating: "\0", count: minCapacity)
        gapStart = 0
        gapEnd = minCapacity
    }

    init(_ text: String) {
        self.init()
        for char in text {
            insert(char)
        }
    }

    var count: Int {
        buffer.count - (gapEnd - gapStart)
    }

    var isEmpty: Bool {
        count == 0
    }

    // MARK: - Core Operations

    /// Move the gap to the specified position
    /// Position is in logical coordinates (not counting the gap)
    mutating func moveGap(to position: Int) {
        let position = min(max(position, 0), count)

        if gapStart == position {
            return
        }

        if position < gapStart {
            // Move gap left
            let shift = gapStart - position
            let srcStart = position
            let dstStart = gapEnd - shift

            for i in 0..<shift {
                buffer[dstStart + i] = buffer[srcStart + i]
            }
            gapStart = position
            gapEnd = gapEnd - shift
        } else {
            // Move gap right
            let shift = position - gapStart
            let srcStart = gapEnd
            let dstStart = gapStart

            for i in 0..<shift {
                buffer[dstStart + i] = buffer[srcStart + i]
            }
            gapStart = gapStart + shift
            gapEnd = gapEnd + shift
        }
    }

    /// Insert a character at the current gap position
    mutating func insert(_ char: Character) {
        if gapStart >= gapEnd {
            expandGap()
        }

        buffer[gapStart] = char
        gapStart += 1
    }

    /// Insert a string at the current gap position
    mutating func insert(_ text: String) {
        for char in text {
            insert(char)
        }
    }

    /// Delete count characters starting at position
    mutating func delete(at position: Int, count: Int = 1) {
        guard count > 0 && position >= 0 && position < self.count else { return }

        moveGap(to: position)
        gapEnd = min(gapEnd + count, buffer.count)
    }

    /// Delete count characters before the gap
    mutating func deleteBackward(count: Int = 1) {
        let deleteCount = min(count, gapStart)
        gapStart -= deleteCount
    }

    /// Get character at logical position (not counting gap)
    func character(at position: Int) -> Character? {
        guard position >= 0 && position < count else { return nil }

        let bufferIndex = logicalToBuffer(position)
        return buffer[bufferIndex]
    }

    /// Get substring from logical positions
    func substring(from start: Int, to end: Int) -> String {
        guard start >= 0 && end <= count && start <= end else { return "" }

        var result = ""
        for i in start..<end {
            if let char = character(at: i) {
                result.append(char)
            }
        }
        return result
    }

    /// Get all text as string
    func text() -> String {
        var result = ""
        for i in 0..<count {
            if let char = character(at: i) {
                result.append(char)
            }
        }
        return result
    }

    // MARK: - Private Helpers

    private mutating func expandGap() {
        let newCapacity = buffer.count * 2
        var newBuffer = Array(repeating: Character("\0"), count: newCapacity)

        var idx = 0

        // Copy before gap
        for i in 0..<gapStart {
            newBuffer[idx] = buffer[i]
            idx += 1
        }

        // Skip gap space in destination (will be filled with nulls)
        let newGapStart = idx
        let newGapEnd = newCapacity - (buffer.count - gapEnd)
        idx = newGapEnd

        // Copy after gap
        for i in gapEnd..<buffer.count {
            newBuffer[idx] = buffer[i]
            idx += 1
        }

        buffer = newBuffer
        gapStart = newGapStart
        gapEnd = newGapEnd
    }

    private func logicalToBuffer(_ position: Int) -> Int {
        if position < gapStart {
            return position
        } else {
            return position + (gapEnd - gapStart)
        }
    }
}
