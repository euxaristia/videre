import Foundation

/// ANSI color codes for syntax highlighting
enum SyntaxColor: String {
    case reset = "\u{001B}[0m"
    case keyword = "\u{001B}[38;5;204m"      // Pink/magenta for keywords
    case type = "\u{001B}[38;5;81m"          // Cyan for types
    case string = "\u{001B}[38;5;186m"       // Yellow for strings
    case number = "\u{001B}[38;5;180m"       // Orange for numbers
    case comment = "\u{001B}[38;5;102m"      // Gray for comments
    case function = "\u{001B}[38;5;117m"     // Light blue for functions
    case preprocessor = "\u{001B}[38;5;140m" // Purple for preprocessor
    case operator_ = "\u{001B}[38;5;145m"    // Light gray for operators
    case constant = "\u{001B}[38;5;173m"     // Brown/orange for constants
    case special = "\u{001B}[38;5;149m"      // Green for special
    case variable = "\u{001B}[38;5;252m"     // White for variables
    case attribute = "\u{001B}[38;5;114m"    // Light green for attributes
    case tag = "\u{001B}[38;5;167m"          // Red for HTML/XML tags
    // Search highlight - yellow background with black text (like neovim)
    case searchMatch = "\u{001B}[30;48;5;220m"  // Black text on yellow background
}

/// Token type for syntax highlighting
enum TokenType {
    case keyword
    case type
    case string
    case number
    case comment
    case function
    case preprocessor
    case `operator`
    case constant
    case special
    case variable
    case attribute
    case tag
    case plain
}

/// A highlighted token
struct HighlightToken {
    let text: String
    let type: TokenType
    let range: Range<String.Index>
}

/// Language definition for syntax highlighting
struct LanguageDefinition {
    let name: String
    let extensions: [String]
    let keywords: Set<String>
    let types: Set<String>
    let constants: Set<String>
    let lineComment: String?
    let blockCommentStart: String?
    let blockCommentEnd: String?
    let stringDelimiters: [Character]
    let preprocessorPrefix: String?
    let operators: Set<String>
    let specialIdentifiers: Set<String>

    init(
        name: String,
        extensions: [String],
        keywords: Set<String> = [],
        types: Set<String> = [],
        constants: Set<String> = [],
        lineComment: String? = nil,
        blockCommentStart: String? = nil,
        blockCommentEnd: String? = nil,
        stringDelimiters: [Character] = ["\"", "'"],
        preprocessorPrefix: String? = nil,
        operators: Set<String> = [],
        specialIdentifiers: Set<String> = []
    ) {
        self.name = name
        self.extensions = extensions
        self.keywords = keywords
        self.types = types
        self.constants = constants
        self.lineComment = lineComment
        self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd
        self.stringDelimiters = stringDelimiters
        self.preprocessorPrefix = preprocessorPrefix
        self.operators = operators
        self.specialIdentifiers = specialIdentifiers
    }
}

/// Main syntax highlighter class
class SyntaxHighlighter {
    private var language: LanguageDefinition?
    private var inBlockComment: Bool = false

    static let shared = SyntaxHighlighter()

    private init() {}

    /// Detect language from file extension
    func detectLanguage(from filePath: String?) -> LanguageDefinition? {
        guard let path = filePath else { return nil }
        let ext = (path as NSString).pathExtension.lowercased()
        return Languages.all.first { $0.extensions.contains(ext) }
    }

    /// Set the current language
    func setLanguage(_ lang: LanguageDefinition?) {
        self.language = lang
        self.inBlockComment = false
    }

    /// Get color for token type
    func colorFor(_ type: TokenType) -> String {
        switch type {
        case .keyword: return SyntaxColor.keyword.rawValue
        case .type: return SyntaxColor.type.rawValue
        case .string: return SyntaxColor.string.rawValue
        case .number: return SyntaxColor.number.rawValue
        case .comment: return SyntaxColor.comment.rawValue
        case .function: return SyntaxColor.function.rawValue
        case .preprocessor: return SyntaxColor.preprocessor.rawValue
        case .operator: return SyntaxColor.operator_.rawValue
        case .constant: return SyntaxColor.constant.rawValue
        case .special: return SyntaxColor.special.rawValue
        case .variable: return SyntaxColor.variable.rawValue
        case .attribute: return SyntaxColor.attribute.rawValue
        case .tag: return SyntaxColor.tag.rawValue
        case .plain: return SyntaxColor.reset.rawValue
        }
    }

    /// Highlight a single line and return colorized string
    func highlightLine(_ line: String) -> String {
        guard let lang = language else { return line }

        var result = ""
        var i = line.startIndex
        let end = line.endIndex

        // Check if we're continuing a block comment
        if inBlockComment {
            if let blockEnd = lang.blockCommentEnd,
               let endRange = line.range(of: blockEnd)
            {
                result += colorFor(.comment)
                result += String(line[..<endRange.upperBound])
                result += SyntaxColor.reset.rawValue
                i = endRange.upperBound
                inBlockComment = false
            } else {
                return colorFor(.comment) + line + SyntaxColor.reset.rawValue
            }
        }

        while i < end {
            // Check for line comment
            if let lineComment = lang.lineComment,
               line[i...].hasPrefix(lineComment)
            {
                result += colorFor(.comment)
                result += String(line[i...])
                result += SyntaxColor.reset.rawValue
                break
            }

            // Check for block comment start
            if let blockStart = lang.blockCommentStart,
               line[i...].hasPrefix(blockStart)
            {
                if let blockEnd = lang.blockCommentEnd,
                   let endRange = line[i...].range(of: blockEnd,
                       range: line.index(i, offsetBy: blockStart.count)..<end)
                {
                    // Block comment on same line
                    result += colorFor(.comment)
                    result += String(line[i..<endRange.upperBound])
                    result += SyntaxColor.reset.rawValue
                    i = endRange.upperBound
                    continue
                } else {
                    // Block comment continues to next line
                    result += colorFor(.comment)
                    result += String(line[i...])
                    result += SyntaxColor.reset.rawValue
                    inBlockComment = true
                    break
                }
            }

            // Check for preprocessor
            if let prefix = lang.preprocessorPrefix {
                let trimmed = String(line[i...]).trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(prefix) && (i == line.startIndex || line[line.index(before: i)].isWhitespace) {
                    result += colorFor(.preprocessor)
                    result += String(line[i...])
                    result += SyntaxColor.reset.rawValue
                    break
                }
            }

            // Check for string
            if lang.stringDelimiters.contains(line[i]) {
                let delimiter = line[i]
                var stringEnd = line.index(after: i)
                var escaped = false

                while stringEnd < end {
                    if escaped {
                        escaped = false
                    } else if line[stringEnd] == "\\" {
                        escaped = true
                    } else if line[stringEnd] == delimiter {
                        stringEnd = line.index(after: stringEnd)
                        break
                    }
                    stringEnd = line.index(after: stringEnd)
                }

                result += colorFor(.string)
                result += String(line[i..<stringEnd])
                result += SyntaxColor.reset.rawValue
                i = stringEnd
                continue
            }

            // Check for number
            if line[i].isNumber || (line[i] == "." && i < line.index(before: end) && line[line.index(after: i)].isNumber) {
                var numEnd = i
                var hasDecimal = line[i] == "."
                var hasExponent = false

                if line[i] == "0" && numEnd < line.index(before: end) {
                    let next = line[line.index(after: numEnd)]
                    if next == "x" || next == "X" {
                        // Hex number
                        numEnd = line.index(numEnd, offsetBy: 2)
                        while numEnd < end && (line[numEnd].isHexDigit || line[numEnd] == "_") {
                            numEnd = line.index(after: numEnd)
                        }
                        result += colorFor(.number)
                        result += String(line[i..<numEnd])
                        result += SyntaxColor.reset.rawValue
                        i = numEnd
                        continue
                    } else if next == "b" || next == "B" {
                        // Binary number
                        numEnd = line.index(numEnd, offsetBy: 2)
                        while numEnd < end && (line[numEnd] == "0" || line[numEnd] == "1" || line[numEnd] == "_") {
                            numEnd = line.index(after: numEnd)
                        }
                        result += colorFor(.number)
                        result += String(line[i..<numEnd])
                        result += SyntaxColor.reset.rawValue
                        i = numEnd
                        continue
                    }
                }

                numEnd = line.index(after: numEnd)
                while numEnd < end {
                    let c = line[numEnd]
                    if c.isNumber || c == "_" {
                        numEnd = line.index(after: numEnd)
                    } else if c == "." && !hasDecimal && !hasExponent {
                        hasDecimal = true
                        numEnd = line.index(after: numEnd)
                    } else if (c == "e" || c == "E") && !hasExponent {
                        hasExponent = true
                        numEnd = line.index(after: numEnd)
                        if numEnd < end && (line[numEnd] == "+" || line[numEnd] == "-") {
                            numEnd = line.index(after: numEnd)
                        }
                    } else if c == "f" || c == "F" || c == "l" || c == "L" || c == "u" || c == "U" {
                        numEnd = line.index(after: numEnd)
                        break
                    } else {
                        break
                    }
                }

                result += colorFor(.number)
                result += String(line[i..<numEnd])
                result += SyntaxColor.reset.rawValue
                i = numEnd
                continue
            }

            // Check for identifier (keyword, type, function, etc.)
            if line[i].isLetter || line[i] == "_" || line[i] == "@" {
                var idEnd = line.index(after: i)
                while idEnd < end && (line[idEnd].isLetter || line[idEnd].isNumber || line[idEnd] == "_") {
                    idEnd = line.index(after: idEnd)
                }

                let identifier = String(line[i..<idEnd])

                // Check if it's followed by ( making it a function call
                var isFunction = false
                var checkIdx = idEnd
                while checkIdx < end && line[checkIdx].isWhitespace {
                    checkIdx = line.index(after: checkIdx)
                }
                if checkIdx < end && line[checkIdx] == "(" {
                    isFunction = true
                }

                if lang.keywords.contains(identifier) {
                    result += colorFor(.keyword)
                } else if lang.types.contains(identifier) {
                    result += colorFor(.type)
                } else if lang.constants.contains(identifier) {
                    result += colorFor(.constant)
                } else if lang.specialIdentifiers.contains(identifier) {
                    result += colorFor(.special)
                } else if identifier.hasPrefix("@") {
                    result += colorFor(.attribute)
                } else if isFunction {
                    result += colorFor(.function)
                } else {
                    result += SyntaxColor.reset.rawValue
                }

                result += identifier
                result += SyntaxColor.reset.rawValue
                i = idEnd
                continue
            }

            // Regular character
            result += String(line[i])
            i = line.index(after: i)
        }

        return result
    }

    /// Reset state for new file
    func reset() {
        inBlockComment = false
    }
}

// MARK: - Character extensions

extension Character {
    var isHexDigit: Bool {
        return isNumber || ("a"..."f").contains(self.lowercased().first ?? " ")
    }
}
