import AppKit
import SwiftUI

public final class SettingsWindow: NSWindowController {
    private let viewModel: SettingsViewModel

    public init(rulesManager: RulesManager) {
        self.viewModel = SettingsViewModel(rulesManager: rulesManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FnX Settings"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel))

        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#if DEBUG
struct SettingsWindow_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel(rulesManager: .init()))
    }
}
#endif
