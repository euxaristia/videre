import Foundation

// MARK: - Copied logic from EditorApp.swift

private func displayWidth(of char: Character) -> Int {
    // Check for Variation Selector-16 (Emoji style) -> Force 2 columns
    if char.unicodeScalars.contains(where: { $0.value == 0xFE0F }) {
        return 2
    }

    guard let scalar = char.unicodeScalars.first else { return 1 }
    let value = scalar.value

    // Zero-width characters (combining marks, zero-width joiners, etc.)
    if (value >= 0x0300 && value <= 0x036F) ||  // Combining Diacritical Marks
       (value >= 0x200B && value <= 0x200F) ||  // Zero-width space, joiners, marks
       (value >= 0xFE00 && value <= 0xFE0F) ||  // Variation Selectors
       (value >= 0xE0100 && value <= 0xE01EF) { // Variation Selectors Supplement
        return 0
    }

    // Wide characters (2 columns)
    // Emoji ranges
    if (value >= 0x1F300 && value <= 0x1F9FF) ||  // Miscellaneous Symbols and Pictographs, Emoticons, etc.
       (value >= 0x1FA00 && value <= 0x1FAFF) ||  // Chess symbols, extended-A
       // REMOVED BROAD RANGE 2600-26FF
       // REMOVED BROAD RANGE 2700-27BF
       (value >= 0x231A && value <= 0x231B) ||    // Watch, Hourglass
       (value >= 0x23E9 && value <= 0x23F3) ||    // Various symbols
       (value >= 0x23F8 && value <= 0x23FA) ||    // Various symbols
       (value >= 0x25AA && value <= 0x25AB) ||    // Squares
       (value >= 0x25B6 && value == 0x25B6) ||    // Play button
       (value >= 0x25C0 && value == 0x25C0) ||    // Reverse button
       (value >= 0x25FB && value <= 0x25FE) ||    // Squares
       (value >= 0x2614 && value <= 0x2615) ||    // Umbrella, hot beverage
       (value >= 0x2648 && value <= 0x2653) ||    // Zodiac
       (value >= 0x267F && value == 0x267F) ||    // Wheelchair
       (value >= 0x2693 && value == 0x2693) ||    // Anchor
       (value >= 0x26A1 && value == 0x26A1) ||    // High voltage
       (value >= 0x26AA && value <= 0x26AB) ||    // Circles
       (value >= 0x26BD && value <= 0x26BE) ||    // Soccer, baseball
       (value >= 0x26C4 && value <= 0x26C5) ||    // Snowman, sun
       (value >= 0x26CE && value == 0x26CE) ||    // Ophiuchus
       (value >= 0x26D4 && value == 0x26D4) ||    // No entry
       (value >= 0x26EA && value == 0x26EA) ||    // Church
       (value >= 0x26F2 && value <= 0x26F3) ||    // Fountain, golf
       (value >= 0x26F5 && value == 0x26F5) ||    // Sailboat
       (value >= 0x26FA && value == 0x26FA) ||    // Tent
       (value >= 0x26FD && value == 0x26FD) ||    // Fuel pump
       (value >= 0x2702 && value == 0x2702) ||    // Scissors
       (value >= 0x2705 && value == 0x2705) ||    // Check mark
       (value >= 0x2708 && value <= 0x270D) ||    // Various
       (value >= 0x270F && value == 0x270F) ||    // Pencil
       (value >= 0x2712 && value == 0x2712) ||    // Black nib
       (value >= 0x2714 && value == 0x2714) ||    // Check mark
       (value >= 0x2716 && value == 0x2716) ||    // X mark
       (value >= 0x271D && value == 0x271D) ||    // Latin cross
       (value >= 0x2721 && value == 0x2721) ||    // Star of David
       (value >= 0x2728 && value == 0x2728) ||    // Sparkles
       (value >= 0x2733 && value <= 0x2734) ||    // Eight spoked asterisk
       (value >= 0x2744 && value == 0x2744) ||    // Snowflake
       (value >= 0x2747 && value == 0x2747) ||    // Sparkle
       (value >= 0x274C && value == 0x274C) ||    // Cross mark
       (value >= 0x274E && value == 0x274E) ||    // Cross mark
       (value >= 0x2753 && value <= 0x2755) ||    // Question marks
       (value >= 0x2757 && value == 0x2757) ||    // Exclamation mark
       (value >= 0x2763 && value <= 0x2764) ||    // Heart exclamation, heart
       (value >= 0x2795 && value <= 0x2797) ||    // Plus, minus, divide
       (value >= 0x27A1 && value == 0x27A1) ||    // Right arrow
       (value >= 0x27B0 && value == 0x27B0) ||    // Curly loop
       (value >= 0x27BF && value == 0x27BF) ||    // Double curly loop
       (value >= 0x2934 && value <= 0x2935) ||    // Arrows
       (value >= 0x2B05 && value <= 0x2B07) ||    // Arrows
       (value >= 0x2B1B && value <= 0x2B1C) ||    // Squares
       (value >= 0x2B50 && value == 0x2B50) ||    // Star
       (value >= 0x2B55 && value == 0x2B55) ||    // Circle
       (value >= 0x3030 && value == 0x3030) ||    // Wavy dash
       (value >= 0x303D && value == 0x303D) ||    // Part alternation mark
       (value >= 0x3297 && value == 0x3297) ||    // Circled Ideograph Congratulation
       (value >= 0x3299 && value == 0x3299) {     // Circled Ideograph Secret
        return 2
    }

    // CJK characters (2 columns)
    if (value >= 0x4E00 && value <= 0x9FFF) ||    // CJK Unified Ideographs
       (value >= 0x3400 && value <= 0x4DBF) ||    // CJK Unified Ideographs Extension A
       (value >= 0x20000 && value <= 0x2A6DF) ||  // CJK Unified Ideographs Extension B
       (value >= 0x2A700 && value <= 0x2CEAF) ||  // CJK Unified Ideographs Extensions C-F
       (value >= 0xF900 && value <= 0xFAFF) ||    // CJK Compatibility Ideographs
       (value >= 0x2F800 && value <= 0x2FA1F) ||  // CJK Compatibility Ideographs Supplement
       (value >= 0x3000 && value <= 0x303F) ||    // CJK Symbols and Punctuation
       (value >= 0xFF00 && value <= 0xFFEF) ||    // Halfwidth and Fullwidth Forms
       (value >= 0x1100 && value <= 0x11FF) ||    // Hangul Jamo
       (value >= 0xAC00 && value <= 0xD7AF) ||    // Hangul Syllables
       (value >= 0x3040 && value <= 0x309F) ||    // Hiragana
       (value >= 0x30A0 && value <= 0x30FF) ||    // Katakana
       (value >= 0x31F0 && value <= 0x31FF) {     // Katakana Phonetic Extensions
        return 2
    }

    // Default: 1 column
    return 1
}

// MARK: - Test Logic

func testFile(_ filePath: String) {
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        print("Failed to read file: \(filePath)")
        return
    }

    let lines = content.split(whereSeparator: \.isNewline).map(String.init)
    
    print("Analyzing \(filePath)...")
    for (i, line) in lines.enumerated() {
        var output = "Line \(i + 1): "
        for char in line {
            let width = displayWidth(of: char)
            let isWide = width == 2
            
            // Format: Char(Width)
            if isWide {
                output += "\(char)(\(width)) "
            } else if char.unicodeScalars.first!.value > 127 {
                // Also print neutral unicode chars to verify they are 1
                output += "\(char)(\(width)) "
            }
        }
        if output != "Line \(i + 1): " {
            print(output)
        }
    }
}

if CommandLine.arguments.count > 1 {
    testFile(CommandLine.arguments[1])
} else {
    print("Usage: swift verify_width.swift <file_path>")
}
