import AppKit

public final class KeyboardMonitor {
    private let onRecordingStarted: () -> Void
    private let onRecordingStopped: () -> Void
    private var globalMonitor: Any?
    private var isFnHeld = false

    public init(onRecordingStarted: @escaping () -> Void, onRecordingStopped: @escaping () -> Void) {
        self.onRecordingStarted = onRecordingStarted
        self.onRecordingStopped = onRecordingStopped
    }

    public func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    public func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)

        if fnPressed && !isFnHeld {
            isFnHeld = true
            onRecordingStarted()
        } else if !fnPressed && isFnHeld {
            isFnHeld = false
            onRecordingStopped()
        }
    }

    deinit {
        stop()
    }
}
