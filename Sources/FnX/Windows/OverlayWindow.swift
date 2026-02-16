import AppKit
import SwiftUI

public final class OverlayWindow: NSWindow {
    private let viewModel = OverlayViewModel()
    private var hideTimer: Timer?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let rootView = OverlayView(viewModel: viewModel).ignoresSafeArea()
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.layer?.isOpaque = false
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = [.maxSize]
        }
        contentView = hostingView
        contentView?.wantsLayer = true
        positionAtTop()
    }

    public func showRecording() {
        hideTimer?.invalidate()
        positionAtTop()
        orderFrontRegardless()
        viewModel.showRecording()
    }

    public func showProcessing() {
        hideTimer?.invalidate()
        viewModel.showProcessing()
    }

    public func showDone() {
        hideTimer?.invalidate()
        viewModel.showDone()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    public func showProRequired() {
        hideTimer?.invalidate()
        positionAtTop()
        orderFrontRegardless()
        viewModel.showProRequired()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    public func showLimitReached() {
        hideTimer?.invalidate()
        positionAtTop()
        orderFrontRegardless()
        viewModel.showLimitReached()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    public func hide() {
        hideTimer?.invalidate()
        viewModel.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.orderOut(nil)
        }
    }

    private func positionAtTop() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        // Top edge of window = top edge of screen — flush with notch/bezel
        let x = sf.midX - frame.width / 2
        let y = sf.maxY - frame.height
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

#if DEBUG
private func makePreviewVM(_ configure: (OverlayViewModel) -> Void) -> OverlayViewModel {
    let vm = OverlayViewModel()
    configure(vm)
    return vm
}

struct OverlayWindow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OverlayView(viewModel: makePreviewVM { $0.showRecording() })
                .previewDisplayName("Recording")
            OverlayView(viewModel: makePreviewVM { $0.showProcessing() })
                .previewDisplayName("Processing")
            OverlayView(viewModel: makePreviewVM { $0.showDone() })
                .previewDisplayName("Done")
            OverlayView(viewModel: makePreviewVM { $0.showLimitReached() })
                .previewDisplayName("Limit")
        }
        .frame(width: 400, height: 100)
        .background(.gray.opacity(0.15))
    }
}
#endif
