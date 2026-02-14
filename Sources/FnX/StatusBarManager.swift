import AppKit

final class StatusBarManager {
    private let statusItem: NSStatusItem
    private let rulesManager: RulesManager
    private let onSettingsRequested: () -> Void
    private let onQuitRequested: () -> Void

    init(rulesManager: RulesManager, onSettingsRequested: @escaping () -> Void, onQuitRequested: @escaping () -> Void) {
        self.rulesManager = rulesManager
        self.onSettingsRequested = onSettingsRequested
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

    func setupMenu() {
        let menu = NSMenu()

        // Rules section
        let rulesHeader = NSMenuItem(title: "Rules", action: nil, keyEquivalent: "")
        rulesHeader.isEnabled = false
        menu.addItem(rulesHeader)

        // "Direct" (no rule) option
        let directItem = NSMenuItem(title: "Direct (no processing)", action: #selector(selectNoRule), keyEquivalent: "")
        directItem.target = self
        directItem.state = rulesManager.activeRule == nil ? .on : .off
        menu.addItem(directItem)

        for rule in rulesManager.rules {
            let item = NSMenuItem(title: rule.name, action: #selector(selectRule(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = rule.id.uuidString
            item.state = rulesManager.activeRule?.id == rule.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsTapped), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit FnX", action: #selector(quitTapped), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setRecording(_ recording: Bool) {
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

    @objc private func settingsTapped() {
        onSettingsRequested()
    }

    @objc private func quitTapped() {
        onQuitRequested()
    }
}
