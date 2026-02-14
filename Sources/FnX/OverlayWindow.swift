import AppKit

final class OverlayWindow: NSWindow {
    private let label = NSTextField(labelWithString: "")
    private let indicator = NSProgressIndicator()
    private let dotView = NSView()
    private var hideTimer: Timer?
    private var pulseTimer: Timer?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupContent()
    }

    private func setupContent() {
        let windowFrame = NSRect(x: 0, y: 0, width: 160, height: 40)
        let container = NSVisualEffectView(frame: windowFrame)
        container.material = NSVisualEffectView.Material.hudWindow
        container.state = NSVisualEffectView.State.active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.autoresizingMask = NSView.AutoresizingMask([.width, .height])

        // Dot indicator (for recording)
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        dotView.layer?.cornerRadius = 5
        dotView.frame = NSRect(x: 12, y: 15, width: 10, height: 10)

        // Spinner (for processing)
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.frame = NSRect(x: 10, y: 10, width: 20, height: 20)
        indicator.isHidden = true

        // Label
        label.frame = NSRect(x: 34, y: 10, width: 116, height: 20)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .left

        container.addSubview(dotView)
        container.addSubview(indicator)
        container.addSubview(label)
        contentView = container
    }

    func showRecording() {
        hideTimer?.invalidate()
        pulseTimer?.invalidate()

        label.stringValue = "Listening..."
        dotView.isHidden = false
        indicator.isHidden = true
        indicator.stopAnimation(nil)

        positionNearMouse()
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 1
        }

        // Pulse animation on the red dot
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let dot = self?.dotView else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                dot.animator().alphaValue = 0.3
            }) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.4
                    dot.animator().alphaValue = 1.0
                }
            }
        }
    }

    func showProcessing() {
        hideTimer?.invalidate()
        pulseTimer?.invalidate()

        label.stringValue = "Processing..."
        dotView.isHidden = true
        indicator.isHidden = false
        indicator.startAnimation(nil)
    }

    func showDone() {
        hideTimer?.invalidate()
        pulseTimer?.invalidate()

        label.stringValue = "Done!"
        dotView.isHidden = true
        indicator.isHidden = true
        indicator.stopAnimation(nil)

        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        hideTimer?.invalidate()
        pulseTimer?.invalidate()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            self.animator().alphaValue = 0
        }) {
            self.orderOut(nil)
        }
    }

    private func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation
        let offset: CGFloat = 20
        setFrameOrigin(NSPoint(
            x: mouseLocation.x + offset,
            y: mouseLocation.y - frame.height - offset
        ))
    }
}
