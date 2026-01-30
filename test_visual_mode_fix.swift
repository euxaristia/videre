#!/usr/bin/env swift

import Foundation

let VITE_PATH = "/home/euxaristia/Documents/Projects/vite/.build/release/vite"
let TIMEOUT: TimeInterval = 5.0

print("🔬 Testing visual mode fix...")

func runViteTest(content: String, input: String) -> (crashed: Bool, output: String) {
    let tempFile = "/tmp/visual_mode_test.txt"
    
    guard FileManager.default.fileExists(atPath: VITE_PATH) else {
        return (true, "Vite binary not found")
    }
    
    do {
        try content.write(toFile: tempFile, atomically: false, encoding: .utf8)
    } catch {
        return (true, "Failed to create test file")
    }
    
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
        
        let inputHandle = pipeIn.fileHandleForWriting
        inputHandle.write(input.data(using: .utf8) ?? Data())
        inputHandle.write("\u{1B}".data(using: .utf8)!)
        inputHandle.write(":q!\n".data(using: .utf8)!)
        inputHandle.closeFile()
        
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
        
        try? FileManager.default.removeItem(atPath: tempFile)
        
        return (crashed, output)
        
    } catch {
        try? FileManager.default.removeItem(atPath: tempFile)
        return (true, "Failed to run: \(error)")
    }
}

// Test the control characters that were crashing before
let testCases = [
    ("Ctrl+V alone", "\u{16}"),
    ("Ctrl+V twice", "\u{16}\u{16}"),
    ("All control chars", "\u{01}\u{02}\u{16}\u{16}\u{12}"),
]

var crashes: [(test: String, input: String, output: String)] = []

for (testName, input) in testCases {
    print("Testing: \(testName)...")
    
    let content = "test line 1\ntest line 2\ntest line 3\n"
    let result = runViteTest(content: content, input: input)
    
    if result.crashed {
        crashes.append((test: testName, input: input, output: result.output))
        print("  ❌ CRASH DETECTED!")
    } else {
        print("  ✅ Passed")
    }
}

print("\n🎯 Visual mode fix test complete!")
if crashes.isEmpty {
    print("✅ All visual mode tests passed! The crash is fixed!")
} else {
    print("💥 Found \(crashes.count) crashes:")
    for (i, crash) in crashes.enumerated() {
        print("\n\(i + 1). \(crash.test)")
        print("   Input: \(crash.input)")
        print("   Output: \(crash.output.prefix(100))...")
    }
}

exit(crashes.isEmpty ? 0 : 1)