import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(FreeBSD)
    import FreeBSD
#elseif canImport(Musl)
    import Musl
#elseif canImport(Glibc)
    import Glibc
#endif

/// Global flag set by signal handler — checked by the main loop.
/// Using sig_atomic_t for async-signal-safety.
private var signalReceived: sig_atomic_t = 0

/// Stored original termios for signal-safe restoration.
/// Set by ViEditor.setupTerminal() so the signal handler can restore
/// without calling any Swift runtime functions.
var savedOriginalTermios = termios()
var hasSavedTermios: Bool = false

/// Signal-safe terminal restoration.
/// Only uses async-signal-safe POSIX functions (write, tcsetattr).
private func signalSafeRestore() {
    // Disable mouse tracking
    let disableMouse = "\u{001B}[?1006l\u{001B}[?1003l"
    disableMouse.withCString { ptr in
        _ = write(STDOUT_FILENO, ptr, strlen(ptr))
    }

    // Leave alternate screen buffer
    let leaveAltScreen = "\u{001B}[?1049l"
    leaveAltScreen.withCString { ptr in
        _ = write(STDOUT_FILENO, ptr, strlen(ptr))
    }

    // Show cursor
    let showCursor = "\u{001B}[?25h"
    showCursor.withCString { ptr in
        _ = write(STDOUT_FILENO, ptr, strlen(ptr))
    }

    // Restore original terminal settings
    if hasSavedTermios {
        tcsetattr(STDIN_FILENO, TCSANOW, &savedOriginalTermios)
    }
}

class SignalHandler {
    /// Check if a signal was received (called from main loop)
    static var wasSignalReceived: Bool {
        return signalReceived != 0
    }

    static func register() {
        signal(SIGINT) { _ in
            signalSafeRestore()
            // Re-raise with default handler to get proper exit status
            signal(SIGINT, SIG_DFL)
            raise(SIGINT)
        }
        signal(SIGTERM) { _ in
            signalSafeRestore()
            signal(SIGTERM, SIG_DFL)
            raise(SIGTERM)
        }
    }
}
