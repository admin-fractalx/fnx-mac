import AppKit
import SwiftUI

public final class OnboardingWindow: NSWindow {
    private let onComplete: () -> Void
    private var hostingController: NSHostingController<OnboardingView>?

    public init(
        audioRecorder: AudioRecorder,
        whisperService: WhisperService,
        onComplete: @escaping () -> Void
    ) {
        self.onComplete = onComplete

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 580),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        center()
        isMovableByWindowBackground = true

        let viewModel = OnboardingViewModel(
            audioRecorder: audioRecorder,
            whisperService: whisperService,
            onComplete: { [weak self] in
                self?.dismiss()
            }
        )

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 580))
        root.wantsLayer = true
        root.layer?.cornerRadius = 28
        root.layer?.masksToBounds = true

        let vibrancy = NSVisualEffectView(frame: root.bounds)
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.blendingMode = .behindWindow
        vibrancy.autoresizingMask = [.width, .height]
        root.addSubview(vibrancy)

        let hosting = NSHostingController(rootView: OnboardingView(viewModel: viewModel))
        hosting.view.frame = root.bounds
        hosting.view.autoresizingMask = [.width, .height]
        root.addSubview(hosting.view)
        hostingController = hosting

        contentView = root
    }

    public func showWithAnimation() {
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        if let layer = contentView?.layer {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: 270, y: 290)
            let scale = CASpringAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.88
            scale.toValue = 1.0
            scale.damping = 14
            scale.stiffness = 120
            scale.mass = 0.8
            scale.duration = scale.settlingDuration
            layer.add(scale, forKey: "entrance")
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }) { [self] in
            orderOut(nil)
            onComplete()
        }
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
}

#if DEBUG
struct OnboardingWindow_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(
            viewModel: OnboardingViewModel(
                audioRecorder: .init(),
                whisperService: .init(),
                onComplete: {}
            )
        )
    }
}
#endif
