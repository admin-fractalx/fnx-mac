import AppKit
import AVFoundation
import QuartzCore

final class OnboardingWindow: NSWindow {
    private var currentPage = 0
    private let totalPages = 5
    private let onComplete: () -> Void

    private let audioRecorder: AudioRecorder
    private let whisperService: WhisperService
    private var tryKeyboardMonitor: Any?
    private var isTryRecording = false

    private let containerView = NSView()
    private var pageViews: [NSView] = []
    private var dots: [NSView] = []
    private let actionButton = NSButton()

    private let micCheck = NSImageView()
    private let accessibilityCheck = NSImageView()
    private var permissionTimer: Timer?

    private let tryTextView = NSTextView()
    private let tryStatusLabel = NSTextField(labelWithString: "")
    private let tryDot = NSView()
    private var tryPulseTimer: Timer?

    // Liquid glass layers
    private var blobLayers: [CAGradientLayer] = []
    private var glowLayer = CALayer()

    private let W: CGFloat = 520
    private let H: CGFloat = 480

    init(
        audioRecorder: AudioRecorder,
        whisperService: WhisperService,
        onComplete: @escaping () -> Void
    ) {
        self.audioRecorder = audioRecorder
        self.whisperService = whisperService
        self.onComplete = onComplete

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
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

        setupChrome()
        buildPages()
        buildDots()
        buildButton()
        showPage(0, animated: false)
    }

    deinit {
        permissionTimer?.invalidate()
        tryPulseTimer?.invalidate()
        if let monitor = tryKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Liquid Glass Chrome

    private func setupChrome() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        root.wantsLayer = true
        root.layer?.cornerRadius = 24
        root.layer?.masksToBounds = true

        // Animated gradient blobs behind the vibrancy
        let blobHost = NSView(frame: root.bounds)
        blobHost.wantsLayer = true
        blobHost.autoresizingMask = [.width, .height]
        blobHost.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

        let colors: [(NSColor, NSColor)] = [
            (.systemBlue.withAlphaComponent(0.35), .systemCyan.withAlphaComponent(0.15)),
            (.systemPurple.withAlphaComponent(0.3), .systemPink.withAlphaComponent(0.12)),
            (.systemTeal.withAlphaComponent(0.25), .systemIndigo.withAlphaComponent(0.1)),
        ]

        let blobSizes: [CGFloat] = [220, 180, 200]
        let positions: [CGPoint] = [
            CGPoint(x: 80, y: H - 120),
            CGPoint(x: W - 100, y: H - 280),
            CGPoint(x: W / 2, y: 80),
        ]

        for (i, (c1, c2)) in colors.enumerated() {
            let blob = CAGradientLayer()
            blob.type = .radial
            blob.colors = [c1.cgColor, c2.cgColor, NSColor.clear.cgColor]
            blob.locations = [0, 0.5, 1]
            blob.startPoint = CGPoint(x: 0.5, y: 0.5)
            blob.endPoint = CGPoint(x: 1, y: 1)
            let s = blobSizes[i]
            blob.frame = CGRect(x: positions[i].x - s / 2, y: positions[i].y - s / 2, width: s, height: s)
            blob.cornerRadius = s / 2
            blobHost.layer?.addSublayer(blob)
            blobLayers.append(blob)
        }

        root.addSubview(blobHost)
        animateBlobs()

        // Vibrancy overlay
        let vibrancy = NSVisualEffectView(frame: root.bounds)
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.blendingMode = .behindWindow
        vibrancy.autoresizingMask = [.width, .height]
        root.addSubview(vibrancy)

        // Subtle inner border for glass edge
        let border = CALayer()
        border.frame = root.bounds
        border.cornerRadius = 24
        border.borderWidth = 0.5
        border.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        root.layer?.addSublayer(border)

        // Top highlight — the liquid glass "catch light"
        let highlight = CAGradientLayer()
        highlight.colors = [
            NSColor.white.withAlphaComponent(0.12).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ]
        highlight.startPoint = CGPoint(x: 0.5, y: 1)
        highlight.endPoint = CGPoint(x: 0.5, y: 0)
        highlight.frame = CGRect(x: 0, y: H - 100, width: W, height: 100)
        root.layer?.addSublayer(highlight)

        containerView.frame = root.bounds
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        root.addSubview(containerView)

        contentView = root
    }

    private func animateBlobs() {
        let offsets: [(dx: CGFloat, dy: CGFloat)] = [(30, -20), (-25, 30), (20, 25)]
        let durations: [CFTimeInterval] = [8, 10, 9]

        for (i, blob) in blobLayers.enumerated() {
            let anim = CABasicAnimation(keyPath: "position")
            anim.fromValue = blob.position
            anim.toValue = CGPoint(
                x: blob.position.x + offsets[i].dx,
                y: blob.position.y + offsets[i].dy
            )
            anim.duration = durations[i]
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            blob.add(anim, forKey: "drift")
        }
    }

    // MARK: - Pages

    private func buildPages() {
        let page1 = makePage(
            icon: "waveform.circle.fill",
            iconSize: 72,
            title: "FnX",
            titleSize: 42,
            subtitle: "Your voice, everywhere.",
            body: "Dictate text into any app with a single key.\nFast, private, and seamless."
        )

        let page2 = makeStepsPage()

        let page3 = makePage(
            icon: "text.badge.checkmark",
            iconSize: 52,
            title: "Smart Rules",
            titleSize: 28,
            subtitle: "Transform your text automatically.",
            body: "Translate, fix grammar, or rewrite\nas code comments — all hands-free."
        )

        let page4 = buildPermissionsPage()
        let page5 = buildTryItPage()

        pageViews = [page1, page2, page3, page4, page5]
        for pv in pageViews {
            pv.frame = containerView.bounds
            pv.autoresizingMask = [.width, .height]
            pv.isHidden = true
            containerView.addSubview(pv)
        }
    }

    private func makePage(
        icon: String,
        iconSize: CGFloat,
        title: String,
        titleSize: CGFloat,
        subtitle: String,
        body: String
    ) -> NSView {
        let page = NSView()
        page.wantsLayer = true

        // Icon with glow
        let iconContainerSize = iconSize * 1.6
        let iconContainer = NSView(frame: NSRect(
            x: (W - iconContainerSize) / 2,
            y: H - 40 - iconContainerSize,
            width: iconContainerSize,
            height: iconContainerSize
        ))
        iconContainer.wantsLayer = true
        iconContainer.layer?.masksToBounds = false

        let glowSize = iconContainerSize + 24
        let glow = CALayer()
        glow.frame = CGRect(
            x: (iconContainerSize - glowSize) / 2,
            y: (iconContainerSize - glowSize) / 2,
            width: glowSize,
            height: glowSize
        )
        glow.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        glow.cornerRadius = glowSize / 2
        let glowPulse = CABasicAnimation(keyPath: "opacity")
        glowPulse.fromValue = 0.4
        glowPulse.toValue = 1.0
        glowPulse.duration = 2.0
        glowPulse.autoreverses = true
        glowPulse.repeatCount = .infinity
        glowPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.add(glowPulse, forKey: "glow")
        iconContainer.layer?.addSublayer(glow)

        let iconView = NSImageView(frame: iconContainer.bounds)
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .thin)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .white
        }
        iconView.imageAlignment = .alignCenter
        iconContainer.addSubview(iconView)
        page.addSubview(iconContainer)

        // Layout: icon bottom edge
        let iconBottom = H - 40 - iconContainerSize

        // Title
        let titleH = titleSize + 12
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 40, y: iconBottom - 24 - titleH, width: W - 80, height: titleH)
        page.addSubview(titleLabel)

        let titleBottom = iconBottom - 24 - titleH

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.65)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 40, y: titleBottom - 14 - 24, width: W - 80, height: 24)
        page.addSubview(subtitleLabel)

        let subtitleBottom = titleBottom - 14 - 24

        // Body
        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        bodyLabel.alignment = .center
        bodyLabel.frame = NSRect(x: 60, y: subtitleBottom - 18 - 60, width: W - 120, height: 60)
        bodyLabel.maximumNumberOfLines = 4
        page.addSubview(bodyLabel)

        return page
    }

    // MARK: - Steps Page (How It Works)

    private func makeStepsPage() -> NSView {
        let page = NSView()
        page.wantsLayer = true

        let titleLabel = NSTextField(labelWithString: "How It Works")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 40, y: H - 80, width: W - 80, height: 38)
        page.addSubview(titleLabel)

        let steps: [(icon: String, label: String, desc: String)] = [
            ("keyboard", "Hold Fn", "Press and hold the\nFunction key"),
            ("mic.fill", "Speak", "Say what you want\nto type"),
            ("text.cursor", "Release", "Text appears at\nyour cursor"),
        ]

        let cardW: CGFloat = 130
        let cardH: CGFloat = 150
        let spacing: CGFloat = 16
        let totalW = CGFloat(steps.count) * cardW + CGFloat(steps.count - 1) * spacing
        let startX = (W - totalW) / 2
        let cardY: CGFloat = H - 290

        for (i, step) in steps.enumerated() {
            let card = NSView(frame: NSRect(
                x: startX + CGFloat(i) * (cardW + spacing),
                y: cardY,
                width: cardW,
                height: cardH
            ))
            card.wantsLayer = true
            card.layer?.cornerRadius = 16
            card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
            card.layer?.borderWidth = 0.5
            card.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor

            // Step number
            let numLabel = NSTextField(labelWithString: "\(i + 1)")
            numLabel.font = .systemFont(ofSize: 11, weight: .bold)
            numLabel.textColor = NSColor.white.withAlphaComponent(0.3)
            numLabel.alignment = .center
            numLabel.frame = NSRect(x: 0, y: cardH - 30, width: cardW, height: 16)
            card.addSubview(numLabel)

            // Icon
            let icon = NSImageView()
            if let img = NSImage(systemSymbolName: step.icon, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .light)
                icon.image = img.withSymbolConfiguration(config)
                icon.contentTintColor = .controlAccentColor
            }
            icon.frame = NSRect(x: (cardW - 36) / 2, y: cardH - 72, width: 36, height: 36)
            icon.imageAlignment = .alignCenter
            card.addSubview(icon)

            // Label
            let lbl = NSTextField(labelWithString: step.label)
            lbl.font = .systemFont(ofSize: 13, weight: .semibold)
            lbl.textColor = .white
            lbl.alignment = .center
            lbl.frame = NSRect(x: 4, y: cardH - 98, width: cardW - 8, height: 18)
            card.addSubview(lbl)

            // Desc
            let desc = NSTextField(wrappingLabelWithString: step.desc)
            desc.font = .systemFont(ofSize: 11, weight: .regular)
            desc.textColor = NSColor.white.withAlphaComponent(0.4)
            desc.alignment = .center
            desc.frame = NSRect(x: 8, y: 8, width: cardW - 16, height: 34)
            desc.maximumNumberOfLines = 2
            card.addSubview(desc)

            page.addSubview(card)

            // Arrow between cards
            if i < steps.count - 1 {
                let arrow = NSImageView()
                if let img = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) {
                    let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                    arrow.image = img.withSymbolConfiguration(config)
                    arrow.contentTintColor = NSColor.white.withAlphaComponent(0.2)
                }
                arrow.frame = NSRect(
                    x: startX + CGFloat(i) * (cardW + spacing) + cardW + 2,
                    y: cardY + cardH / 2 - 8,
                    width: 12,
                    height: 16
                )
                page.addSubview(arrow)
            }
        }

        // Bottom hint
        let hint = NSTextField(labelWithString: "Works in any text field across macOS.")
        hint.font = .systemFont(ofSize: 13, weight: .regular)
        hint.textColor = NSColor.white.withAlphaComponent(0.35)
        hint.alignment = .center
        hint.frame = NSRect(x: 40, y: H - 350, width: W - 80, height: 20)
        page.addSubview(hint)

        return page
    }

    // MARK: - Permissions Page

    private func buildPermissionsPage() -> NSView {
        let page = NSView()
        page.wantsLayer = true

        // Icon with glow
        let iconContainer = NSView(frame: NSRect(x: (W - 90) / 2, y: H - 150, width: 90, height: 90))
        iconContainer.wantsLayer = true

        let glow = CALayer()
        glow.frame = iconContainer.bounds.insetBy(dx: -8, dy: -8)
        glow.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        glow.cornerRadius = glow.frame.width / 2
        iconContainer.layer?.addSublayer(glow)

        let iconView = NSImageView(frame: iconContainer.bounds)
        if let img = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .thin)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .white
        }
        iconView.imageAlignment = .alignCenter
        iconContainer.addSubview(iconView)
        page.addSubview(iconContainer)

        let titleLabel = NSTextField(labelWithString: "Permissions")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 40, y: H - 210, width: W - 80, height: 38)
        page.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "FnX needs these to work properly.")
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 40, y: H - 240, width: W - 80, height: 20)
        page.addSubview(subtitleLabel)

        let rowWidth: CGFloat = 400
        let rowX = (W - rowWidth) / 2

        let micRow = makePermissionRow(
            icon: "mic.fill",
            title: "Microphone",
            description: "Record your voice for transcription.",
            checkView: micCheck,
            buttonTitle: "Allow",
            action: #selector(requestMicPermission),
            frame: NSRect(x: rowX, y: H - 318, width: rowWidth, height: 60)
        )
        page.addSubview(micRow)

        let accRow = makePermissionRow(
            icon: "universal.access",
            title: "Accessibility",
            description: "Listen for the Fn key & type text for you.",
            checkView: accessibilityCheck,
            buttonTitle: "Open Settings",
            action: #selector(openAccessibilitySettings),
            frame: NSRect(x: rowX, y: H - 390, width: rowWidth, height: 60)
        )
        page.addSubview(accRow)

        return page
    }

    private func makePermissionRow(
        icon: String,
        title: String,
        description: String,
        checkView: NSImageView,
        buttonTitle: String,
        action: Selector,
        frame: NSRect
    ) -> NSView {
        let row = NSView(frame: frame)
        row.wantsLayer = true
        row.layer?.cornerRadius = 14
        row.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
        row.layer?.borderWidth = 0.5
        row.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        let iconBg = NSView(frame: NSRect(x: 14, y: 14, width: 32, height: 32))
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 8
        iconBg.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        row.addSubview(iconBg)

        let iconView = NSImageView(frame: NSRect(x: 4, y: 4, width: 24, height: 24))
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .controlAccentColor
        }
        iconView.imageAlignment = .alignCenter
        iconBg.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 56, y: 34, width: 180, height: 18)
        row.addSubview(titleLabel)

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        descLabel.frame = NSRect(x: 56, y: 12, width: 220, height: 16)
        row.addSubview(descLabel)

        let btn = NSButton(title: buttonTitle, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .regular
        btn.font = .systemFont(ofSize: 12, weight: .medium)
        btn.frame = NSRect(x: frame.width - 128, y: 16, width: 90, height: 28)
        row.addSubview(btn)

        checkView.frame = NSRect(x: frame.width - 32, y: 20, width: 22, height: 22)
        checkView.imageAlignment = .alignCenter
        setCheckState(checkView, granted: false)
        row.addSubview(checkView)

        return row
    }

    private func setCheckState(_ imageView: NSImageView, granted: Bool) {
        let name = granted ? "checkmark.circle.fill" : "circle.dashed"
        let color: NSColor = granted ? .systemGreen : NSColor.white.withAlphaComponent(0.25)
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            imageView.image = img.withSymbolConfiguration(config)
            imageView.contentTintColor = color
        }
    }

    @objc private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPermissionStates() }
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermissionStates() {
        let micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let prevMic = micCheck.contentTintColor == .systemGreen
        setCheckState(micCheck, granted: micGranted)
        if micGranted && !prevMic { animateCheckmark(micCheck) }

        let accGranted = AXIsProcessTrusted()
        let prevAcc = accessibilityCheck.contentTintColor == .systemGreen
        setCheckState(accessibilityCheck, granted: accGranted)
        if accGranted && !prevAcc { animateCheckmark(accessibilityCheck) }

        updateButtonForPermissions()
    }

    private func animateCheckmark(_ view: NSImageView) {
        let origY = view.frame.origin.y
        view.alphaValue = 0
        view.frame.origin.y = origY - 6
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1
            view.animator().frame.origin.y = origY
        }
    }

    private func updateButtonForPermissions() {
        if currentPage == 3 {
            let micOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            let accOK = AXIsProcessTrusted()
            actionButton.isEnabled = micOK && accOK
            actionButton.title = (micOK && accOK) ? "Continue" : "Grant Permissions"
        }
    }

    private func startPermissionPolling() {
        refreshPermissionStates()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshPermissionStates()
        }
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: - Try It Page

    private func buildTryItPage() -> NSView {
        let page = NSView()
        page.wantsLayer = true

        // Icon
        let iconContainer = NSView(frame: NSRect(x: (W - 90) / 2, y: H - 140, width: 90, height: 90))
        iconContainer.wantsLayer = true

        let glow = CALayer()
        glow.frame = iconContainer.bounds.insetBy(dx: -8, dy: -8)
        glow.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        glow.cornerRadius = glow.frame.width / 2
        iconContainer.layer?.addSublayer(glow)

        let iconView = NSImageView(frame: iconContainer.bounds)
        if let img = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 44, weight: .thin)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .white
        }
        iconView.imageAlignment = .alignCenter
        iconContainer.addSubview(iconView)
        page.addSubview(iconContainer)

        let titleLabel = NSTextField(labelWithString: "Try It!")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 40, y: H - 200, width: W - 80, height: 38)
        page.addSubview(titleLabel)

        // Status pill
        let pillW: CGFloat = 220
        let pill = NSView(frame: NSRect(x: (W - pillW) / 2, y: H - 244, width: pillW, height: 30))
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 15
        pill.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
        pill.layer?.borderWidth = 0.5
        pill.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        tryDot.wantsLayer = true
        tryDot.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        tryDot.layer?.cornerRadius = 4.5
        tryDot.frame = NSRect(x: 14, y: 11, width: 9, height: 9)
        pill.addSubview(tryDot)

        tryStatusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        tryStatusLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        tryStatusLabel.alignment = .left
        tryStatusLabel.stringValue = "Hold Fn and speak..."
        tryStatusLabel.frame = NSRect(x: 30, y: 5, width: pillW - 40, height: 20)
        pill.addSubview(tryStatusLabel)
        page.addSubview(pill)

        // Text view
        let textW: CGFloat = W - 80
        let textH: CGFloat = 150
        let scrollContainer = NSView(frame: NSRect(x: 40, y: H - 420, width: textW, height: textH))
        scrollContainer.wantsLayer = true
        scrollContainer.layer?.cornerRadius = 14
        scrollContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        scrollContainer.layer?.borderWidth = 0.5
        scrollContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        scrollContainer.layer?.masksToBounds = true

        let scrollView = NSScrollView(frame: scrollContainer.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.scrollerStyle = .overlay

        tryTextView.frame = NSRect(x: 0, y: 0, width: textW, height: textH)
        tryTextView.isEditable = false
        tryTextView.isSelectable = true
        tryTextView.font = .systemFont(ofSize: 14, weight: .regular)
        tryTextView.textColor = .white
        tryTextView.backgroundColor = .clear
        tryTextView.textContainerInset = NSSize(width: 14, height: 14)
        tryTextView.isRichText = false
        tryTextView.string = ""
        tryTextView.drawsBackground = false

        scrollView.documentView = tryTextView
        scrollContainer.addSubview(scrollView)
        page.addSubview(scrollContainer)

        // Placeholder
        let placeholder = NSTextField(labelWithString: "Your transcription will appear here...")
        placeholder.font = .systemFont(ofSize: 13, weight: .regular)
        placeholder.textColor = NSColor.white.withAlphaComponent(0.2)
        placeholder.alignment = .center
        placeholder.tag = 999
        placeholder.frame = NSRect(x: 40, y: H - 360, width: textW, height: 20)
        page.addSubview(placeholder)

        return page
    }

    private func startTryItMonitor() {
        let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleTryFlagsChanged(event)
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleTryFlagsChanged(event)
        }
        tryKeyboardMonitor = (local as Any, global as Any)
    }

    private func stopTryItMonitor() {
        if let monitors = tryKeyboardMonitor as? (Any, Any) {
            NSEvent.removeMonitor(monitors.0)
            NSEvent.removeMonitor(monitors.1)
        }
        tryKeyboardMonitor = nil
        tryPulseTimer?.invalidate()
        tryPulseTimer = nil
    }

    private func handleTryFlagsChanged(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)
        if fnPressed && !isTryRecording {
            isTryRecording = true
            startTryRecording()
        } else if !fnPressed && isTryRecording {
            isTryRecording = false
            stopTryRecording()
        }
    }

    private func startTryRecording() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tryStatusLabel.stringValue = "Listening..."
            self.tryStatusLabel.textColor = NSColor.white.withAlphaComponent(0.85)
            self.tryDot.layer?.backgroundColor = NSColor.systemRed.cgColor

            self.tryPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
                guard let dot = self?.tryDot else { return }
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

        do {
            try audioRecorder.startRecording()
        } catch {
            isTryRecording = false
            DispatchQueue.main.async { [weak self] in
                self?.tryStatusLabel.stringValue = "Recording failed. Try again."
                self?.tryDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            }
        }
    }

    private func stopTryRecording() {
        audioRecorder.stopRecording()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tryPulseTimer?.invalidate()
            self.tryPulseTimer = nil
            self.tryDot.alphaValue = 1
            self.tryDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            self.tryStatusLabel.stringValue = "Processing..."
        }

        guard let audioURL = audioRecorder.lastRecordingURL else {
            DispatchQueue.main.async { [weak self] in
                self?.tryStatusLabel.stringValue = "Hold Fn and speak..."
                self?.tryStatusLabel.textColor = NSColor.white.withAlphaComponent(0.6)
                self?.tryDot.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            }
            return
        }

        let apiKey = Secrets.openAIAPIKey

        Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await self.whisperService.transcribe(fileURL: audioURL, apiKey: apiKey)

                await MainActor.run {
                    if let placeholder = self.pageViews[4].viewWithTag(999) {
                        placeholder.isHidden = true
                    }
                    if !self.tryTextView.string.isEmpty {
                        self.tryTextView.string += "\n"
                    }
                    self.tryTextView.string += text
                    self.tryDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
                    self.tryStatusLabel.stringValue = "Done! Try again or continue."
                    self.tryStatusLabel.textColor = NSColor.white.withAlphaComponent(0.7)
                    self.tryTextView.scrollToEndOfDocument(nil)
                }
            } catch {
                await MainActor.run {
                    self.tryDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
                    self.tryStatusLabel.stringValue = "Error. Hold Fn to retry."
                    self.tryStatusLabel.textColor = NSColor.white.withAlphaComponent(0.6)
                }
            }

            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    // MARK: - Dots

    private func buildDots() {
        let dotSize: CGFloat = 7
        let activeW: CGFloat = 22
        let spacing: CGFloat = 6
        let totalWidth = activeW + CGFloat(totalPages - 1) * (dotSize + spacing) - spacing + spacing
        let startX = (W - totalWidth) / 2
        let y: CGFloat = 58

        for i in 0..<totalPages {
            let isActive = i == 0
            let w = isActive ? activeW : dotSize
            let dot = NSView(frame: NSRect(
                x: startX + CGFloat(i) * (dotSize + spacing),
                y: y,
                width: w,
                height: dotSize
            ))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2
            dot.layer?.backgroundColor = isActive
                ? NSColor.white.withAlphaComponent(0.9).cgColor
                : NSColor.white.withAlphaComponent(0.2).cgColor
            containerView.addSubview(dot)
            dots.append(dot)
        }
    }

    private func updateDots() {
        let dotSize: CGFloat = 7
        let activeW: CGFloat = 22
        let spacing: CGFloat = 6

        var xOffset: CGFloat = 0
        let totalWidth: CGFloat = activeW + CGFloat(totalPages - 1) * dotSize + CGFloat(totalPages - 1) * spacing
        let startX = (W - totalWidth) / 2

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (i, dot) in dots.enumerated() {
                let isActive = i == currentPage
                let w = isActive ? activeW : dotSize
                dot.animator().frame = NSRect(
                    x: startX + xOffset,
                    y: dot.frame.origin.y,
                    width: w,
                    height: dotSize
                )
                dot.layer?.backgroundColor = isActive
                    ? NSColor.white.withAlphaComponent(0.9).cgColor
                    : NSColor.white.withAlphaComponent(0.2).cgColor
                xOffset += w + spacing
            }
        }
    }

    // MARK: - Button

    private func buildButton() {
        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .large
        actionButton.font = .systemFont(ofSize: 14, weight: .semibold)
        actionButton.target = self
        actionButton.action = #selector(buttonTapped)
        actionButton.frame = NSRect(x: (W - 160) / 2, y: 16, width: 160, height: 36)
        containerView.addSubview(actionButton)
        updateButtonTitle()
    }

    private func updateButtonTitle() {
        actionButton.isEnabled = true
        switch currentPage {
        case 3:
            let micOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            let accOK = AXIsProcessTrusted()
            actionButton.isEnabled = micOK && accOK
            actionButton.title = (micOK && accOK) ? "Continue" : "Grant Permissions"
        case totalPages - 1:
            actionButton.title = "Get Started"
        default:
            actionButton.title = "Continue"
        }
    }

    @objc private func buttonTapped() {
        if currentPage < totalPages - 1 {
            showPage(currentPage + 1, animated: true)
        } else {
            stopTryItMonitor()
            dismiss()
        }
    }

    // MARK: - Navigation

    private func showPage(_ index: Int, animated: Bool) {
        let previousPage = currentPage
        currentPage = index
        updateDots()
        updateButtonTitle()

        if index == 3 { startPermissionPolling() }
        else if previousPage == 3 { stopPermissionPolling() }

        if index == 4 { startTryItMonitor() }
        else if previousPage == 4 { stopTryItMonitor() }

        if animated {
            let outgoing = pageViews[previousPage]
            let incoming = pageViews[index]

            incoming.alphaValue = 0
            incoming.isHidden = false

            let direction: CGFloat = index > previousPage ? -30 : 30
            incoming.frame.origin.x = -direction

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.45
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
                outgoing.animator().alphaValue = 0
                outgoing.animator().frame.origin.x = direction
                incoming.animator().alphaValue = 1
                incoming.animator().frame.origin.x = 0
            }) {
                outgoing.isHidden = true
                outgoing.frame.origin.x = 0
            }
        } else {
            for (i, pv) in pageViews.enumerated() {
                pv.isHidden = i != index
                pv.alphaValue = i == index ? 1 : 0
            }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        stopPermissionPolling()
        stopTryItMonitor()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }) { [self] in
            self.orderOut(nil)
            self.onComplete()
        }
    }

    // MARK: - Entrance

    func showWithAnimation() {
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        if let layer = contentView?.layer {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: W / 2, y: H / 2)

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
            self.animator().alphaValue = 1
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
