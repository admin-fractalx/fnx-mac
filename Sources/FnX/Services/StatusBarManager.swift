import AppKit

public final class StatusBarManager {
    private let statusItem: NSStatusItem
    private let rulesManager: RulesManager
    private let licenseManager: LicenseManager
    private let onSettingsRequested: () -> Void
    private let onLicenseRequested: () -> Void
    private let onQuitRequested: () -> Void

    public init(
        rulesManager: RulesManager,
        licenseManager: LicenseManager,
        onSettingsRequested: @escaping () -> Void,
        onLicenseRequested: @escaping () -> Void,
        onQuitRequested: @escaping () -> Void
    ) {
        self.rulesManager = rulesManager
        self.licenseManager = licenseManager
        self.onSettingsRequested = onSettingsRequested
        self.onLicenseRequested = onLicenseRequested
        self.onQuitRequested = onQuitRequested
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        setupButton()
        setupMenu()
    }

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "FnX")
            button.image?.isTemplate = true
        }
    }

    public func setupMenu() {
        let menu = NSMenu()

        let isPro = licenseManager.tier == .pro
        if isPro {
            let header = NSMenuItem(title: "FnX Pro", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        } else {
            let remaining = licenseManager.remainingToday
            let header = NSMenuItem(title: "FnX Free — \(remaining)/\(licenseManager.dailyLimit) left", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }

        menu.addItem(NSMenuItem.separator())

        let rulesHeader = NSMenuItem(title: "Rules", action: nil, keyEquivalent: "")
        rulesHeader.isEnabled = false
        menu.addItem(rulesHeader)

        let directItem = NSMenuItem(title: "Direct (no processing)", action: #selector(selectNoRule), keyEquivalent: "")
        directItem.target = self
        directItem.state = rulesManager.activeRule == nil ? .on : .off
        menu.addItem(directItem)

        for rule in rulesManager.rules {
            let tag: String
            if rule.useWhisperTranslate {
                tag = " — Offline"
            } else if isPro {
                tag = " — AI"
            } else {
                tag = " — AI (Pro)"
            }
            let item = NSMenuItem(title: "\(rule.name)\(tag)", action: #selector(selectRule(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = rule.id.uuidString
            item.state = rulesManager.activeRule?.id == rule.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let licenseTitle = isPro ? "Manage License..." : "Upgrade to Pro..."
        let licenseItem = NSMenuItem(title: licenseTitle, action: #selector(licenseTapped), keyEquivalent: "")
        licenseItem.target = self
        menu.addItem(licenseItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsTapped), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit FnX", action: #selector(quitTapped), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    public func setRecording(_ recording: Bool) {
        if let button = statusItem.button {
            if recording {
                button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
                button.contentTintColor = .systemRed
            } else {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "FnX")
                button.contentTintColor = nil
                button.image?.isTemplate = true
            }
        }
    }

    @objc private func selectNoRule() {
        rulesManager.activeRuleID = nil
        setupMenu()
    }

    @objc private func selectRule(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let uuid = UUID(uuidString: idString) else { return }
        rulesManager.activeRuleID = uuid
        setupMenu()
    }

    @objc private func licenseTapped() {
        onLicenseRequested()
    }

    @objc private func settingsTapped() {
        onSettingsRequested()
    }

    @objc private func quitTapped() {
        onQuitRequested()
    }
}
