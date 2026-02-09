import Foundation

typealias SignalCallback = () -> Void

class SignalHandler {
    private static var callbacks: [SignalCallback] = []

    static func register(callback: @escaping SignalCallback) {
        callbacks.append(callback)
        
        signal(SIGINT) { _ in SignalHandler.handleSignal() }
        signal(SIGTERM) { _ in SignalHandler.handleSignal() }
    }

    private static func handleSignal() {
        for callback in callbacks {
            callback()
        }
        exit(0)
    }
}
