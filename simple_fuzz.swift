#!/usr/bin/env swift

import Foundation

// Simple fuzzing script for vite editor
// This directly tests the vite binary with various inputs

let VITE_PATH = "/home/euxaristia/Documents/Projects/vite/.build/release/vite"
let FUZZ_ITERATIONS = 100
let MAX_INPUT_SIZE = 1000
let TIMEOUT: TimeInterval = 2.0

print("🔬 Starting simple vite fuzzing...")

// Test cases that might cause crashes
let testCases = [
    // Edge case: Very large line numbers
    ("Extreme line motion", "9999999999G"),
    ("Extreme right motion", "9999999999l"),
    ("Extreme left motion", "9999999999h"),
    ("Extreme down motion", "9999999999j"),
    ("Extreme up motion", "9999999999k"),
    
    // Edge case: Control characters
    ("Control characters", "\u{01}\u{02}\u{16}\u{16}\u{12}"),
    ("Many backspaces", "9999\u{7F}"),
    
    // Edge case: Unicode and special characters
    ("Unicode characters", "￿￿￿￿￿￿￿￿￿￿"),
    ("Null bytes", "\u{0}\u{0}\u{0}\u{0}\u{0}"),
    ("Escape sequences", "\u{1B}[999;999H"),
    
    // Edge case: File operations
    ("Delete entire file", "ggdG"),
    ("Yank entire file", "ggVGy"),
    ("Invalid file write", ":w /tmp/nonexistent/path/file.txt\n"),
    ("Open nonexistent", ":e nonexistent_file.txt\n"),
    
    // Edge case: Motion combinations
    ("Many word motions", "ggw" + String(repeating: "w", count: 100)),
    ("Many backward words", "ggb" + String(repeating: "b", count: 100)),
    ("Line start to end", "0$"),
    ("File start to line end", "gg$"),
    
    // Edge case: Bracket matching
    ("Unmatched brackets", "((((((((((()))))))))))"),
    ("Mixed brackets", "([{}])"),
    ("Find matching bracket", "gg%"),
    
    // Edge case: Insert mode operations
    ("Many new lines", String(repeating: "o\n", count: 50)),
    ("Many new lines above", String(repeating: "O\n", count: 50)),
]

var crashes: [(test: String, input: String, output: String)] = []

func runViteTest(content: String, input: String) -> (crashed: Bool, output: String) {
    let tempFile = "/tmp/vite_fuzz_test_" + UUID().uuidString + ".txt"
    
    // Check if vite exists
    guard FileManager.default.fileExists(atPath: VITE_PATH) else {
        return (true, "Vite binary not found at \(VITE_PATH)")
    }
    
    // Create test file
    do {
        try content.write(toFile: tempFile, atomically: false, encoding: .utf8)
    } catch {
        print("Failed to create test file: \(error)")
        return (true, "Failed to create test file")
    }
    
    // Run vite with timeout
    let process = Process()
    process.executableURL = URL(fileURLWithPath: VITE_PATH)
    process.arguments = [tempFile]
    
    let pipeIn = Pipe()
    let pipeOut = Pipe()
    let pipeErr = Pipe()
    
    process.standardInput = pipeIn
    process.standardOutput = pipeOut
    process.standardError = pipeErr
    
    do {
        try process.run()
        
        // Send input and quit command
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
        
        let waitResult = semaphore.wait(timeout: DispatchTime.now() + TIMEOUT)
        if waitResult == .timedOut {
            timedOut = true
            process.terminate()
            process.waitUntilExit()
        }
        
        let stdoutData = pipeOut.fileHandleForReading.readDataToEndOfFile()
        let stderrData = pipeErr.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        let output = stdout + stderr
        let crashed = timedOut || finalExitCode != 0
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: tempFile)
        
        return (crashed, output)
        
    } catch {
        try? FileManager.default.removeItem(atPath: tempFile)
        return (true, "Failed to run: \(error)")
    }
}

// Run all test cases
for (testName, input) in testCases {
    print("Testing: \(testName)...")
    
    // Test with normal content
    let normalContent = "This is a test file with multiple lines\nLine 2\nLine 3\n"
    let result = runViteTest(content: normalContent, input: input)
    
    if result.crashed {
        crashes.append((test: testName + " (normal content)", input: input, output: result.output))
        print("  ❌ CRASH DETECTED!")
    } else {
        print("  ✅ Passed")
    }
    
    // Test with edge case content (large file)
    let largeContent = String(repeating: "test line\n", count: 1000)
    let result2 = runViteTest(content: largeContent, input: input)
    
    if result2.crashed {
        crashes.append((test: testName + " (large content)", input: input, output: result2.output))
        print("  ❌ CRASH DETECTED with large content!")
    } else {
        print("  ✅ Passed with large content")
    }
}

// Test with random inputs
print("\n🎲 Testing random inputs...")
for i in 0..<FUZZ_ITERATIONS {
    let randomChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\n\t\r "
    let randomLength = Int.random(in: 1..<MAX_INPUT_SIZE)
    let randomInput = String((0..<randomLength).map { _ in randomChars.randomElement()! })
    
    let content = String(repeating: "test line\n", count: 100)
    let result = runViteTest(content: content, input: randomInput)
    
    if result.crashed {
        crashes.append((test: "Random Test \(i)", input: randomInput, output: result.output))
        print("  ❌ CRASH DETECTED in random test \(i)!")
    }
    
    if i % 10 == 0 {
        print("  Completed \(i)/\(FUZZ_ITERATIONS) random tests...")
    }
}

print("\n🎯 Fuzzing complete!")
if crashes.isEmpty {
    print("✅ No crashes found!")
} else {
    print("💥 Found \(crashes.count) potential crashes:")
    for (i, crash) in crashes.enumerated() {
        print("\n\(i + 1). \(crash.test)")
        print("   Input: \(crash.input.prefix(100))...")
        print("   Output: \(crash.output.prefix(200))...")
    }
}

exit(crashes.isEmpty ? 0 : 1)