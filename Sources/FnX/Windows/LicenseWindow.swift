import AppKit
import SwiftUI

public final class LicenseWindow: NSWindowController {
    private let viewModel: LicenseViewModel

    public init(licenseManager: LicenseManager, onUpdate: @escaping () -> Void) {
        self.viewModel = LicenseViewModel(licenseManager: licenseManager, onUpdate: onUpdate)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FnX Pro"
        window.center()
        window.contentView = NSHostingView(rootView: LicenseView(viewModel: viewModel))

        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func refreshState() {
        viewModel.refresh()
    }
}

#if DEBUG
struct LicenseWindow_Previews: PreviewProvider {
    static var previews: some View {
        LicenseView(
            viewModel: LicenseViewModel(
                licenseManager: .init(),
                onUpdate: {}
            )
        )
    }
}
#endif
