import AppKit
import Carbon.HIToolbox

final class TextInjector {
    func type(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Use Unicode string injection via CGEvent
        let chars = Array(text.utf16)
        let chunkSize = 20 // CGEvent supports up to 20 Unicode chars at a time

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

            // Small delay between chunks to avoid dropped characters
            usleep(5000) // 5ms
        }
    }
}
