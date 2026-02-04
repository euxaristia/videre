import XCTest

@testable import videre

/// Port of the Python InputFuzzer logic to Swift
class InputFuzzer {
    struct FuzzConfig {
        var maxSequenceLength: Int = 100
        var minSequenceLength: Int = 5
        var includeSpecialKeys: Bool = true
        var includeUnicode: Bool = true
        var seed: UInt64? = nil
    }

    let config: FuzzConfig
    var rng: AnyRandomNumberGenerator

    // Abstracted key representation matching internal handling
    // We use characters just like the editor does internally
    let specialKeys: [Character] = [
        "\u{03}",  // Ctrl+C
        "\u{1B}",  // ESC
        "\t",  // Tab
        "\u{7F}",  // Backspace (mapped in NormalMode)
        " ",  // Space
        "↑", "↓", "←", "→",  // Arrows (mapped in EditorApp)
        "↖", "↘",  // Home, End
        "⌦",  // Delete
        "\u{01}",  // Ctrl+A
        "\u{18}",  // Ctrl+X
        "\u{02}",  // Ctrl+B
        "\u{06}",  // Ctrl+F
        "\u{12}",  // Ctrl+R
    ]

    let unicodeChars: [Character] = [
        "α", "β", "γ", "δ", "é", "ñ", "ü", "ç", "ø", "æ",
        "€", "¥", "£", "©", "®", "™", "°", "±", "×", "÷",
    ]

    let wideChars: [Character] = [
        "😀", "😎", "🎉", "🔥", "💨", "✨", "🍅", "🚀", "🦀", "✅",
        "❌", "⚙️", "📁", "💾", "🔍", "⚠️", "🐛", "🎯", "💡", "🔧",
        "中", "文", "日", "本", "語", "한", "국", "어",
    ]

    let complexEmoji: [Character] = [
        "👨‍👩‍👧‍👦", "👨‍⚕️", "👩‍⚖️", "🏳️‍🌈",
    ]

    init(config: FuzzConfig = FuzzConfig()) {
        self.config = config
        if let seed = config.seed {
            self.rng = AnyRandomNumberGenerator(LinearCongruentialGenerator(seed: seed))
        } else {
            self.rng = AnyRandomNumberGenerator(SystemRandomNumberGenerator())
        }
    }

    func generateSequence(length: Int? = nil) -> [Character] {
        let len =
            length
            ?? Int.random(in: config.minSequenceLength...config.maxSequenceLength, using: &rng)
        var sequence: [Character] = []

        for _ in 0..<len {
            let choice = Double.random(in: 0...1, using: &rng)

            if choice < 0.55 {
                // Regular ASCII
                let ascii =
                    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}\\|;':\",./<>?"
                sequence.append(ascii.randomElement(using: &rng)!)
            } else if choice < 0.70 && config.includeSpecialKeys {
                sequence.append(specialKeys.randomElement(using: &rng)!)
            } else if choice < 0.95 && config.includeUnicode {
                // Simplified unicode distribution
                let subChoice = Double.random(in: 0...1, using: &rng)
                if subChoice < 0.3 {
                    sequence.append(wideChars.randomElement(using: &rng)!)
                } else if subChoice < 0.6 {
                    sequence.append(unicodeChars.randomElement(using: &rng)!)
                } else {
                    sequence.append(complexEmoji.randomElement(using: &rng)!)
                }
            } else {
                // Escape sequence simulation (ESC + char)
                sequence.append("\u{1B}")
                sequence.append("hjkl".randomElement(using: &rng)!)
            }
        }

        return sequence
    }

    func generateEdgeCases() -> [[Character]] {
        var cases: [[Character]] = []

        // Rapid key presses
        cases.append(Array(repeating: "h", count: 50))
        cases.append(Array(repeating: "j", count: 50))

        // Large file navigation
        cases.append(Array("G" + String(repeating: "j", count: 100) + "gg" + "G"))

        // Invalid commands
        cases.append(Array(":!<invalid>\r"))  // \r for Enter

        // ZWJ stress
        let zwjSeq = Array(
            "i" + String(repeating: "👨‍👩‍👧‍👦", count: 5) + "\u{1B}0" + String(repeating: "x", count: 5))
        cases.append(zwjSeq)

        return cases
    }
    func generateStressSequences() -> [[Character]] {
        var sequences: [[Character]] = []

        // Extreme rapid movements
        sequences.append(Array(repeating: "h", count: 200))
        sequences.append(Array(repeating: "j", count: 200))

        // Rapid mode switching
        sequences.append(
            Array(
                "i" + String(repeating: "a", count: 50) + "\u{1B}o"
                    + String(repeating: "a", count: 50) + "\u{1B}"))

        // Command mode stress
        sequences.append(Array(":" + String(repeating: "1", count: 100) + "\r"))

        // Visual mode stress
        sequences.append(Array("v" + String(repeating: "l", count: 100) + "d"))

        // Undo/redo stress
        sequences.append(
            Array(String(repeating: "iHello\u{1B}ui\u{1B}ui\u{1B}ui\u{1B}", count: 20)))

        // ZWJ sequence soup
        let zwjSoup = Array("i" + String(repeating: "\u{200D}😀", count: 50) + "\u{1B}")
        sequences.append(zwjSoup)

        return sequences
    }

    func generateMovementSequence(length: Int = 20) -> [Character] {
        let movements: [Character] = [
            "↑", "↓", "←", "→", "↖", "↘", "\u{06}", "\u{02}", "g", "G", "0", "$",
        ]
        var sequence: [Character] = []

        for _ in 0..<length {
            if Double.random(in: 0...1, using: &rng) < 0.8 {
                sequence.append(movements.randomElement(using: &rng)!)
            } else {
                sequence.append(["i", "\u{1B}", "a", "o", "O"].randomElement(using: &rng)!)
            }
        }
        return sequence
    }

    func generateInsertionSequence(length: Int = 50) -> [Character] {
        let text = "The quick brown fox jumps over the lazy dog. "
        var sequence: [Character] = ["i"]
        let charsToInsert = Int.random(in: 10...length, using: &rng)

        for _ in 0..<charsToInsert {
            let char = (text + "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ")
                .randomElement(using: &rng)!
            sequence.append(char)
        }
        sequence.append("\u{1B}")
        return sequence
    }

    struct BehaviorTest {
        let name: String
        let sequence: [Character]
        let shouldExit: Bool
        let description: String
    }

    func generateBehaviorTests() -> [BehaviorTest] {
        var tests: [BehaviorTest] = []

        // Ctrl+C check
        tests.append(
            BehaviorTest(
                name: "ctrl_c_no_exit", sequence: ["\u{03}"], shouldExit: false,
                description: "Ctrl+C should not exit"))
        tests.append(
            BehaviorTest(
                name: "ctrl_c_repeated", sequence: ["\u{03}", "\u{03}", "\u{03}"],
                shouldExit: false, description: "Repeated Ctrl+C should not exit"))

        // Navigation should not exit
        for key: Character in ["↑", "↓", "←", "→", "↖", "↘"] {
            tests.append(
                BehaviorTest(
                    name: "nav_no_exit", sequence: [key], shouldExit: false,
                    description: "Navigation should not exit"))
        }

        // Basic edits should not exit
        for key: Character in ["\u{7F}", "⌦", "\t", " ", "\u{1B}"] {
            tests.append(
                BehaviorTest(
                    name: "edit_no_exit", sequence: [key], shouldExit: false,
                    description: "Basic edit keys should not exit"))
        }

        // Ctrl keys should not exit
        for char in "abdfglnpruvxz" {
            // We'd map these to control codes if we had a full mapper, but for now check known ones
            // \u{01} is Ctrl+A, etc.
            // Let's just check the ones we defined in specialKeys for now to avoid complexity
        }

        return tests
    }
}

// Simple LCG for deterministic seeding if needed
struct LinearCongruentialGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = 6_364_136_223_846_793_005 &* state &+ 1_442_695_040_888_963_407
        return state
    }
}

// Type eraser for RNG
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    var _next: () -> UInt64

    init<G: RandomNumberGenerator>(_ generator: G) {
        var g = generator
        _next = { g.next() }
    }

    mutating func next() -> UInt64 {
        return _next()
    }
}

final class FuzzTests: XCTestCase {

    func testFuzzing() {
        let fuzzer = InputFuzzer()
        let iterations = 10

        for i in 0..<iterations {
            let sequence = fuzzer.generateSequence()
            print("Running sequence \(i): \(String(sequence))")
            runFuzzSequence(sequence, description: "Random sequence \(i)")
        }
    }

    func testEdgeCases() {
        let fuzzer = InputFuzzer()
        let cases = fuzzer.generateEdgeCases()

        for (index, sequence) in cases.enumerated() {
            print("Running edge case \(index): \(String(sequence))")
            runFuzzSequence(sequence, description: "Edge case \(index)")
        }
    }

    private func setupEditorState() -> EditorState {
        let state = EditorState()
        state.buffer = TextBuffer(
            "The quick brown fox jumps over the lazy dog.\n"
                + String(repeating: "Line content\n", count: 20))

        // Initialize all modes and wire them up
        // Note: In EditorApp this is done lazily/deferred, but for tests we force it
        // to ensure we don't hit nil Optionals during rapid fuzzing

        let normal = NormalMode(state: state)
        let insert = InsertMode(state: state)
        let visual = VisualMode(state: state)
        let command = CommandMode(state: state)
        let search = SearchMode(state: state)

        state.normalModeHandler = normal
        state.insertModeHandler = insert
        state.visualModeHandler = visual
        state.commandModeHandler = command
        state.searchModeHandler = search

        state.currentMode = .normal

        return state
        // In a real fuzzer we might check invariants here
        // e.g. state.cursor.position is valid
    }

    func testStress() {
        let fuzzer = InputFuzzer()
        let sequences = fuzzer.generateStressSequences()

        for (index, sequence) in sequences.enumerated() {
            print("Running stress test \(index)")
            runFuzzSequence(sequence, description: "Stress test \(index)")
        }
    }

    func testBehavior() {
        let fuzzer = InputFuzzer()
        let tests = fuzzer.generateBehaviorTests()

        for test in tests {
            print("Running behavior test: \(test.name)")
            runBehaviorTest(test)
        }
    }

    func testSpecializedGenerators() {
        let fuzzer = InputFuzzer()

        print("Running movement sequence")
        runFuzzSequence(fuzzer.generateMovementSequence(), description: "Movement sequence")

        print("Running insertion sequence")
        runFuzzSequence(fuzzer.generateInsertionSequence(), description: "Insertion sequence")
    }

    private func runBehaviorTest(_ test: InputFuzzer.BehaviorTest) {
        let state = setupEditorState()

        for char in test.sequence {
            switch state.currentMode {
            case .normal: _ = state.normalModeHandler?.handleInput(char)
            case .insert: _ = state.insertModeHandler?.handleInput(char)
            case .visual, .visualLine, .visualBlock: _ = state.visualModeHandler?.handleInput(char)
            case .command: _ = state.commandModeHandler?.handleInput(char)
            case .search: _ = state.searchModeHandler?.handleInput(char)
            }
        }

        XCTAssertEqual(
            state.shouldExit, test.shouldExit,
            "Test failed: \(test.name) - \(test.description). shouldExit was \(state.shouldExit)")
    }

    private func runFuzzSequence(_ sequence: [Character], description: String) {
        let state = setupEditorState()

        for char in sequence {
            // Full dispatch logic restored
            switch state.currentMode {
            case .normal:
                _ = state.normalModeHandler?.handleInput(char)
            case .insert:
                _ = state.insertModeHandler?.handleInput(char)
            case .visual, .visualLine, .visualBlock:
                _ = state.visualModeHandler?.handleInput(char)
            case .command:
                _ = state.commandModeHandler?.handleInput(char)
            case .search:
                _ = state.searchModeHandler?.handleInput(char)
            }

            // In a real fuzzer we might check invariants here
            // e.g. state.cursor.position is valid
        }
    }
}
