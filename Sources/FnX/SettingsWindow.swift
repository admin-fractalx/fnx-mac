import AppKit

final class SettingsWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let rulesManager: RulesManager
    private let tableView = NSTableView()
    private var rules: [Rule] = []

    init(rulesManager: RulesManager) {
        self.rulesManager = rulesManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FnX Settings"
        window.center()

        super.init(window: window)
        setupUI()
        loadData()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let padding: CGFloat = 20
        var y: CGFloat = 310

        // Rules section
        let rulesLabel = NSTextField(labelWithString: "Rules:")
        rulesLabel.frame = NSRect(x: padding, y: y, width: 460, height: 20)
        rulesLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        contentView.addSubview(rulesLabel)

        y -= 220
        let scrollView = NSScrollView(frame: NSRect(x: padding, y: y, width: 460, height: 210))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 120

        let promptColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("prompt"))
        promptColumn.title = "Prompt"
        promptColumn.width = 320

        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(promptColumn)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 24

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Buttons
        y -= 35
        let addButton = NSButton(title: "Add Rule", target: self, action: #selector(addRule))
        addButton.frame = NSRect(x: padding, y: y, width: 100, height: 24)
        addButton.bezelStyle = .rounded
        contentView.addSubview(addButton)

        let editButton = NSButton(title: "Edit", target: self, action: #selector(editRule))
        editButton.frame = NSRect(x: 130, y: y, width: 80, height: 24)
        editButton.bezelStyle = .rounded
        contentView.addSubview(editButton)

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteRule))
        deleteButton.frame = NSRect(x: 220, y: y, width: 80, height: 24)
        deleteButton.bezelStyle = .rounded
        contentView.addSubview(deleteButton)
    }

    private func loadData() {
        rules = rulesManager.rules
        tableView.reloadData()
    }

    @objc private func addRule() {
        showRuleEditor(rule: nil)
    }

    @objc private func editRule() {
        let row = tableView.selectedRow
        guard row >= 0, row < rules.count else { return }
        showRuleEditor(rule: rules[row])
    }

    @objc private func deleteRule() {
        let row = tableView.selectedRow
        guard row >= 0, row < rules.count else { return }
        rulesManager.deleteRule(id: rules[row].id)
        loadData()
    }

    private func showRuleEditor(rule: Rule?) {
        let alert = NSAlert()
        alert.messageText = rule == nil ? "New Rule" : "Edit Rule"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))

        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.frame = NSRect(x: 0, y: 75, width: 300, height: 20)
        container.addSubview(nameLabel)

        let nameField = NSTextField(frame: NSRect(x: 0, y: 50, width: 300, height: 24))
        nameField.stringValue = rule?.name ?? ""
        container.addSubview(nameField)

        let promptLabel = NSTextField(labelWithString: "Prompt:")
        promptLabel.frame = NSRect(x: 0, y: 25, width: 300, height: 20)
        container.addSubview(promptLabel)

        let promptField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        promptField.stringValue = rule?.prompt ?? ""
        container.addSubview(promptField)

        alert.accessoryView = container

        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let prompt = promptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }

            if var existing = rule {
                existing.name = name
                existing.prompt = prompt
                rulesManager.updateRule(existing)
            } else {
                rulesManager.addRule(Rule(name: name, prompt: prompt))
            }
            loadData()
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        rules.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rule = rules[row]
        let text: String
        if tableColumn?.identifier.rawValue == "name" {
            text = rule.name
        } else {
            text = rule.prompt
        }

        let cellID = NSUserInterfaceItemIdentifier("Cell")
        let cell: NSTextField
        if let existing = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField {
            cell = existing
        } else {
            cell = NSTextField(labelWithString: "")
            cell.identifier = cellID
            cell.lineBreakMode = .byTruncatingTail
        }
        cell.stringValue = text
        return cell
    }
}
