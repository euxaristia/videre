import Foundation

/// Register content type
enum RegisterContent {
    case characters(String)
    case lines([String])
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
        let validNames = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\"-*+/")
        guard validNames.contains(name) else { return nil }

        return registers[name]
    }

    func set(_ name: Character, _ content: RegisterContent) {
        let validNames = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\"-*+/")
        guard validNames.contains(name) else { return }

        registers[name] = content

        // Also update unnamed register on any write
        unnamed = content
    }

    func append(_ name: Character, _ content: RegisterContent) {
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
