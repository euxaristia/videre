#!/usr/bin/env swift

import Foundation

// Fuzzing harness for Vite (Swift vi editor)
// This targets critical components that could cause crashes

// Fuzzer configuration
let FUZZ_ITERATIONS = 10000
let MAX_INPUT_SIZE = 10000

// Create fuzzing workspace
let fuzzDir = "/tmp/vite_fuzz_\(UUID().uuidString)"
do {
    try FileManager.default.createDirectory(atPath: fuzzDir, withIntermediateDirectories: true)
} catch {
    print("Failed to create fuzzing directory: \(error)")
    exit(1)
}

print("🔬 Starting Vite fuzzing campaign...")
print("📁 Workspace: \(fuzzDir)")

// Mark: - Fuzzing Data Generators

struct FuzzData {
    static func randomString(length: Int) -> String {
        let baseChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let controlChars = "\n\t\r\u{08}"
        let specialChars2 = " ~!@#$%^&*()_+-=[]{}|;':\",./<>?`/"
        let chars = baseChars + controlChars + specialChars2
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    static func randomUnicodeString(length: Int) -> String {
        let basicMultilingualPlane: [UnicodeScalar] = (0x0000...0xFFFF).compactMap { UnicodeScalar($0) }
        return String((0..<length).map { _ in Character(basicMultilingualPlane.randomElement()!) })
    }
    
    static func maliciousString() -> String {
        let patterns = [
            String(repeating: "\n", count: 1000),  // Many newlines
            String(repeating: "\t", count: 1000),  // Many tabs
            String(repeating: " ", count: 10000), // Many spaces
            String(repeating: "\0", count: 100),   // Null bytes
            String(repeating: "\u{1B}", count: 100), // Escape sequences
            String(repeating: "￿", count: 100),    // High Unicode
            "\u{FEFF}" + randomString(length: 100), // BOM + content
            randomUnicodeString(length: 1000),     // Random Unicode
            randomString(length: 1000) + "\u{4}" + randomString(length: 1000), // Control chars
        ]
        return patterns.randomElement()!
    }
}

// Mark: - Test Harness

class FuzzHarness {
    let workspace: String
    
    init(workspace: String) {
        self.workspace = workspace
    }
    
    func createTestFile(content: String) -> String {
        let filename = "\(workspace)/test_\(UUID().uuidString).txt"
        do {
            try content.write(toFile: filename, atomically: false, encoding: .utf8)
            return filename
        } catch {
            print("Failed to create test file: \(error)")
            return ""
        }
    }
    
    func runViteWithFile(_ filename: String, input: String, timeout: TimeInterval = 5.0) -> (exitCode: Int32, stdout: String, stderr: String, crashed: Bool) {
        let process = Process()
        let vitePath = "/home/euxaristia/Documents/Projects/vite/.build/release/vite"
        
        // Check if vite exists
        guard FileManager.default.fileExists(atPath: vitePath) else {
            return (
                exitCode: -1,
                stdout: "",
                stderr: "Vite binary not found at \(vitePath)",
                crashed: true
            )
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filename) else {
            return (
                exitCode: -1,
                stdout: "",
                stderr: "Test file not found at \(filename)",
                crashed: true
            )
        }
        
        process.executableURL = URL(fileURLWithPath: vitePath)
        process.arguments = [filename]
        
        let pipeIn = Pipe()
        let pipeOut = Pipe()
        let pipeErr = Pipe()
        
        process.standardInput = pipeIn
        process.standardOutput = pipeOut
        process.standardError = pipeErr
        
        do {
            try process.run()
            
            // Send input and quit
            let inputHandle = pipeIn.fileHandleForWriting
            inputHandle.write(input.data(using: .utf8) ?? Data())
            inputHandle.write(":q!\n".data(using: .utf8)!)
            inputHandle.closeFile()
            
            // Wait with timeout using proper concurrency
            let semaphore = DispatchSemaphore(value: 0)
            var finalExitCode: Int32 = 0
            var timedOut = false
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                finalExitCode = process.terminationStatus
                semaphore.signal()
            }
            
            let waitResult = semaphore.wait(timeout: DispatchTime.now() + timeout)
            if waitResult == .timedOut {
                timedOut = true
                process.terminate()
                process.waitUntilExit()
            }
            
            let stdoutData = pipeOut.fileHandleForReading.readDataToEndOfFile()
            let stderrData = pipeErr.fileHandleForReading.readDataToEndOfFile()
            
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            
            return (
                exitCode: finalExitCode,
                stdout: stdout,
                stderr: stderr,
                crashed: timedOut || finalExitCode != 0
            )
        } catch {
            return (
                exitCode: -1,
                stdout: "",
                stderr: "Failed to run: \(error)",
                crashed: true
            )
        }
    }
}

// Mark: - Fuzz Tests

class FuzzTests {
    let harness: FuzzHarness
    var crashes: [(test: String, input: String, file: String, output: String)] = []
    
    init(harness: FuzzHarness) {
        self.harness = harness
    }
    
    func runAllTests() {
        print("🧪 Running fuzz tests...")
        
        testLargeFiles()
        testMalformedUnicode()
        testEscapeSequences()
        testSpecialCharacters()
        testExtremeLineLengths()
        testEmptyAndWhitespace()
        testControlCharacters()
        testBracketMatching()
        testMotionCommands()
        testFileOperations()
        
        print("\n🎯 Fuzzing complete!")
        if crashes.isEmpty {
            print("✅ No crashes found!")
        } else {
            print("💥 Found \(crashes.count) potential crashes:")
            for (i, crash) in crashes.enumerated() {
                print("\(i + 1). \(crash.test)")
                print("   File: \(crash.file)")
                print("   Input: \(crash.input.prefix(100))...")
                print("   Output: \(crash.output.prefix(200))...")
                print("")
            }
        }
    }
    
    private func safeRunTest(name: String, file: String, input: String) {
        guard !file.isEmpty else {
            print("   ⚠️  Skipping \(name) - failed to create test file")
            return
        }
        
        let result = harness.runViteWithFile(file, input: input)
        
        if result.crashed {
            crashes.append((
                test: name,
                input: input,
                file: file,
                output: result.stderr
            ))
        }
        
        // Cleanup test file
        try? FileManager.default.removeItem(atPath: file)
    }
    
    private func testLargeFiles() {
        print("   📄 Testing large files...")
        for i in 0..<100 {
            let content = FuzzData.randomString(length: Int.random(in: 1000...MAX_INPUT_SIZE))
            let file = harness.createTestFile(content: content)
            let input = FuzzData.randomString(length: 100)
            safeRunTest(name: "Large File Test \(i)", file: file, input: input)
        }
    }
    
    private func testMalformedUnicode() {
        print("   🌐 Testing malformed Unicode...")
        for i in 0..<50 {
            let content = FuzzData.randomUnicodeString(length: Int.random(in: 100...2000))
            let file = harness.createTestFile(content: content)
            let input = FuzzData.maliciousString()
            safeRunTest(name: "Unicode Test \(i)", file: file, input: input)
        }
    }
    
    private func testEscapeSequences() {
        print("   ⌨️  Testing escape sequences...")
        let escapeInputs = [
            String(repeating: "\u{1B}", count: 100),  // Many ESCs
            "\u{1B}[" + String(repeating: "A", count: 100),  // Invalid ANSI
            "\u{1B}[999;999H",  // Out of bounds cursor
            "\u{1B}[?999h",     // Invalid mode
            "\u{1B}[38;5;999m", // Invalid color
            "\u{1B}]8;;http://example.com\u{1B}\\", // Hyperlink
        ]
        
        for (i, input) in escapeInputs.enumerated() {
            let file = harness.createTestFile(content: "test content")
            safeRunTest(name: "Escape Sequence Test \(i)", file: file, input: input)
        }
    }
    
    private func testSpecialCharacters() {
        print("   🔣 Testing special characters...")
        let specialChars = "\u{0}\t\n\r\u{08}\u{7}\u{11}\u{13}\u{14}\u{1B}\u{7F}￿"
        for i in 0..<50 {
            let content = String(repeating: specialChars, count: Int.random(in: 1...100))
            let file = harness.createTestFile(content: content)
            let input = String(repeating: specialChars, count: 20)
            safeRunTest(name: "Special Characters Test \(i)", file: file, input: input)
        }
    }
    
    private func testExtremeLineLengths() {
        print("   📏 Testing extreme line lengths...")
        for i in 0..<30 {
            let longLine = String(repeating: "x", count: Int.random(in: 10000...50000)) + "\n"
            let content = String(repeating: longLine, count: 10)
            let file = harness.createTestFile(content: content)
            let input = "9999G"  // Go to extreme line number
            safeRunTest(name: "Extreme Line Length Test \(i)", file: file, input: input)
        }
    }
    
    private func testEmptyAndWhitespace() {
        print("   📝 Testing empty and whitespace files...")
        let whitespaceContent = [
            "",  // Empty
            " ", // Space
            "\n", // Just newline
            String(repeating: "\n", count: 100),  // Many newlines
            String(repeating: " ", count: 1000),  // Many spaces
            String(repeating: "\t", count: 100),  // Many tabs
            " \n \n \n ", // Mixed whitespace
        ]
        
        for (i, content) in whitespaceContent.enumerated() {
            let file = harness.createTestFile(content: content)
            let input = "gg$d"  // Delete from start
            safeRunTest(name: "Whitespace Test \(i)", file: file, input: input)
        }
    }
    
    private func testControlCharacters() {
        print("   🎮 Testing control character sequences...")
        let controlInputs = [
            "\u{01}",      // Ctrl+A
            "\u{02}",      // Ctrl+B
            "\u{16}\u{16}",// Ctrl+X repeated
            "\u{12}",      // Ctrl+R
            "9999\u{7F}",  // Many backspaces
            "\u{09}",      // Tab
            "\u{0D}",      // Enter
        ]
        
        for (i, input) in controlInputs.enumerated() {
            let file = harness.createTestFile(content: "test content\nmore content")
            safeRunTest(name: "Control Character Test \(i)", file: file, input: input)
        }
    }
    
    private func testBracketMatching() {
        print("   🧮 Testing bracket matching edge cases...")
        let bracketContent = [
            String(repeating: "(", count: 1000) + String(repeating: ")", count: 1000),
            String(repeating: "[", count: 1000) + String(repeating: "]", count: 1000),
            "((((((((((()))))))))))", // Nested
            "([{}])",                 // Mixed
            String(repeating: "{", count: 500), // Unmatched
            "))))((((((",             // Reverse order
        ]
        
        for (i, content) in bracketContent.enumerated() {
            let file = harness.createTestFile(content: content)
            let input = "gg%"  // Find matching bracket
            safeRunTest(name: "Bracket Matching Test \(i)", file: file, input: input)
        }
    }
    
    private func testMotionCommands() {
        print("   🏃 Testing motion command edge cases...")
        let motionInputs = [
            "999999999G",     // Extreme line number
            "9999999999l",    // Extreme right motion
            "9999999999h",    // Extreme left motion
            "9999999999j",    // Extreme down motion
            "9999999999k",    // Extreme up motion
            "ggw" + String(repeating: "w", count: 1000), // Many word motions
            "ggb" + String(repeating: "b", count: 1000), // Many backward word motions
            "0$",             // Line start to end
            "gg$",            // File start to line end
        ]
        
        for (i, input) in motionInputs.enumerated() {
            let file = harness.createTestFile(content: String(repeating: "word ", count: 1000))
            safeRunTest(name: "Motion Command Test \(i)", file: file, input: input)
        }
    }
    
    private func testFileOperations() {
        print("   💾 Testing file operations...")
        let fileOps = [
            ":w /tmp/nonexistent/path/file.txt\n",  // Write to invalid path
            ":e nonexistent_file.txt\n",           // Open nonexistent
            ":r /dev/zero\n",                       // Read from device
            ":!cat /dev/urandom\n",                // Shell command with random data
            String(repeating: "o\n", count: 100),   // Many new lines
            String(repeating: "O\n", count: 100),   // Many new lines above
            "ggdG",                                  // Delete entire file
            "ggVGy",                                 // Yank entire file
        ]
        
        for (i, input) in fileOps.enumerated() {
            let file = harness.createTestFile(content: "test content")
            safeRunTest(name: "File Operation Test \(i)", file: file, input: input)
        }
    }
}

// Mark: - Main Execution

// First, build the project in release mode
print("🔨 Building Vite in release mode...")
let buildProcess = Process()
buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
buildProcess.arguments = ["build", "-c", "release"]
buildProcess.currentDirectoryURL = URL(fileURLWithPath: "/home/euxaristia/Documents/Projects/vite")
do {
    try buildProcess.run()
    buildProcess.waitUntilExit()
} catch {
    print("❌ Failed to build Vite: \(error)")
    exit(1)
}

if buildProcess.terminationStatus != 0 {
    print("❌ Failed to build Vite")
    exit(1)
}

print("✅ Build successful")

// Run fuzzing tests
let harness = FuzzHarness(workspace: fuzzDir)
let tests = FuzzTests(harness: harness)
tests.runAllTests()

// Cleanup
try? FileManager.default.removeItem(atPath: fuzzDir)

print("🧹 Cleanup complete")

// Exit with error code if crashes found
exit(tests.crashes.isEmpty ? 0 : 1)