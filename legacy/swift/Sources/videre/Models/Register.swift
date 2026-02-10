import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Register content type
enum RegisterContent {
    case characters(String)
    case lines([String])
}

/// Helper for system clipboard interaction
private struct SystemClipboard {
    static func copy(_ text: String) {
        #if os(Linux)
            // Try Wayland first
            if !runCommand("wl-copy", args: [], input: text) {
                // Fallback to X11
                _ = runCommand("xclip", args: ["-selection", "clipboard"], input: text)
            }
        #elseif os(macOS)
            _ = runCommand("pbcopy", args: [], input: text)
        #endif
    }

    static func paste() -> String? {
        #if os(Linux)
            // Try Wayland first
            if let content = runCommandOutput("wl-paste", args: ["--no-newline"]) {
                return content
            }
            // Fallback to X11
            return runCommandOutput("xclip", args: ["-selection", "clipboard", "-o"])
        #elseif os(macOS)
            return runCommandOutput("pbpaste", args: [])
        #else
            return nil
        #endif
    }

    private static func runCommand(_ command: String, args: [String], input: String) -> Bool {
        var pid: pid_t = 0
        let argv: [String] = [command] + args
        let cArgs = argv.map { $0.withCString(strdup) } + [nil]
        
        // Pass environment explicitly to ensure Wayland/X11 vars are present
        let env = ProcessInfo.processInfo.environment
        let cEnv = env.map { "\($0.key)=\($0.value)".withCString(strdup) } + [nil]
        
        #if os(Linux)
        var fileActions = posix_spawn_file_actions_t()
        #else
        var fileActions: posix_spawn_file_actions_t? = nil
        #endif
        
        posix_spawn_file_actions_init(&fileActions)
        
        var pipeFds: [Int32] = [0, 0]
        _ = pipeFds.withUnsafeMutableBufferPointer { pipe($0.baseAddress!) }
        let readFd = pipeFds[0]
        let writeFd = pipeFds[1]
        
        // Setup stdin pipe
        posix_spawn_file_actions_adddup2(&fileActions, readFd, 0)
        posix_spawn_file_actions_addclose(&fileActions, writeFd)
        
        // Redirect stdout/stderr to /dev/null
        let devNull = open("/dev/null", O_WRONLY)
        posix_spawn_file_actions_adddup2(&fileActions, devNull, 1)
        posix_spawn_file_actions_adddup2(&fileActions, devNull, 2)
        
        // Use posix_spawnp to search PATH
        let result = posix_spawnp(&pid, command, &fileActions, nil, 
            cArgs.map { $0.map(UnsafeMutablePointer.init) }, 
            cEnv.map { $0.map(UnsafeMutablePointer.init) })
            
        close(readFd)
        close(devNull)
        
        if result == 0 {
            if let data = input.data(using: .utf8) {
                data.withUnsafeBytes { buffer in
                    if let base = buffer.baseAddress {
                        _ = write(writeFd, base, buffer.count)
                    }
                }
            }
            close(writeFd)
            
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            
            cArgs.compactMap { $0 }.forEach { free($0) }
            cEnv.compactMap { $0 }.forEach { free($0) }
            posix_spawn_file_actions_destroy(&fileActions)
            
            return status == 0
        } else {
            cArgs.compactMap { $0 }.forEach { free($0) }
            cEnv.compactMap { $0 }.forEach { free($0) }
            posix_spawn_file_actions_destroy(&fileActions)
            return false
        }
    }

    private static func runCommandOutput(_ command: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/null"))

        do {
            try process.run()
            
            // Read data before waiting for exit to avoid deadlock on full pipe
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

/// Manages vim registers for copy/paste
class RegisterManager {
    private var registers: [Character: RegisterContent] = [:]
    var unnamed: RegisterContent = .characters("") {
        didSet {
            registers["\""] = unnamed
        }
    }

    init() {
        // Initialize unnamed register
        registers["\""] = .characters("")
    }

    // MARK: - Access

    func get(_ name: Character) -> RegisterContent? {
        // System clipboard registers
        if name == "*" || name == "+" {
            if let text = SystemClipboard.paste() {
                return .characters(text)
            }
            return nil
        }

        let validNames = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\"-*+/")
        guard validNames.contains(name) else { return nil }

        return registers[name]
    }

    func set(_ name: Character, _ content: RegisterContent) {
        // System clipboard registers
        if name == "*" || name == "+" {
            let text: String
            switch content {
            case .characters(let s): text = s
            case .lines(let l): text = l.joined(separator: "\n")
            }
            SystemClipboard.copy(text)
            return
        }

        let validNames = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\"-*+/")
        guard validNames.contains(name) else { return }

        registers[name] = content

        // Also update unnamed register on any write (except blackhole usually, but simplifying)
        unnamed = content
    }

    func append(_ name: Character, _ content: RegisterContent) {
        // System clipboard append is tricky, for now just overwrite or fetch-append-set
        if name == "*" || name == "+" {
            if let current = get(name) {
                let text: String
                switch content {
                case .characters(let s): text = s
                case .lines(let l): text = l.joined(separator: "\n")
                }
                
                // Fetch current system clipboard
                if case .characters(let currentText) = current {
                    SystemClipboard.copy(currentText + text)
                } else {
                    SystemClipboard.copy(text)
                }
            } else {
                set(name, content)
            }
            return
        }

        guard let existing = registers[name] else {
            set(name, content)
            return
        }

        let appended: RegisterContent
        switch (existing, content) {
        case (.characters(let str1), .characters(let str2)):
            appended = .characters(str1 + str2)
        case (.lines(let lines1), .lines(let lines2)):
            appended = .lines(lines1 + lines2)
        case (.characters(let str), .lines(let lines)):
            appended = .lines([str] + lines)
        case (.lines(let lines), .characters(let str)):
            appended = .lines(lines + [str])
        }

        registers[name] = appended
        unnamed = appended
    }

    // MARK: - Special Registers

    func getUnnamedRegister() -> RegisterContent {
        return unnamed
    }

    func setUnnamedRegister(_ content: RegisterContent) {
        unnamed = content
    }

    func putRegister() -> RegisterContent {
        // p uses the unnamed register
        return unnamed
    }

    func yankRegister(_ name: Character) {
        // Yank to register - handled by caller
    }
}