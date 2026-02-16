import AppKit
import Carbon.HIToolbox

public final class TextInjector {
    public init() {}

    public func type(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        let chars = Array(text.utf16)
        let chunkSize = 20

        for i in stride(from: 0, to: chars.count, by: chunkSize) {
            let end = min(i + chunkSize, chars.count)
            var chunk = Array(chars[i..<end])
            let length = chunk.count

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDown.keyboardSetUnicodeString(stringLength: length, unicodeString: &chunk)
                keyDown.post(tap: .cghidEventTap)
            }

            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.keyboardSetUnicodeString(stringLength: length, unicodeString: &chunk)
                keyUp.post(tap: .cghidEventTap)
            }

            usleep(5000)
        }
    }
}
