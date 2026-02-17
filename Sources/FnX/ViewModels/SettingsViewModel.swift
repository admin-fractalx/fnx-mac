import Combine
import Foundation

final class SettingsViewModel: ObservableObject {
    @Published private(set) var rules: [Rule] = []
    @Published var selectedRuleID: UUID?
    @Published var editingRule: Rule?
    @Published var isShowingEditor = false
    @Published var editorName = ""
    @Published var editorPrompt = ""
    @Published var editorUseTranslate = false

    private let rulesManager: RulesManager

    var selectedRule: Rule? {
        guard let id = selectedRuleID else { return nil }
        return rules.first { $0.id == id }
    }

    var canEditSelected: Bool {
        selectedRule?.isDefault != true
    }

    var canDeleteSelected: Bool {
        selectedRule?.isDefault != true
    }

    init(rulesManager: RulesManager) {
        self.rulesManager = rulesManager
        loadRules()
    }

    func loadRules() {
        rules = rulesManager.rules
    }

    func addRule() {
        editingRule = nil
        editorName = ""
        editorPrompt = ""
        editorUseTranslate = false
        isShowingEditor = true
    }

    func editSelected() {
        guard let rule = selectedRule else { return }
        editingRule = rule
        editorName = rule.name
        editorPrompt = rule.prompt
        editorUseTranslate = rule.useTranslation
        isShowingEditor = true
    }

    func deleteSelected() {
        guard let id = selectedRuleID,
              rules.contains(where: { $0.id == id }) else { return }
        rulesManager.deleteRule(id: id)
        selectedRuleID = nil
        loadRules()
    }

    func saveRule() {
        let name = editorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = editorUseTranslate ? "" : editorPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if var existing = editingRule {
            existing.name = name
            existing.prompt = prompt
            existing.useTranslation = editorUseTranslate
            rulesManager.updateRule(existing)
        } else {
            rulesManager.addRule(Rule(name: name, prompt: prompt, useTranslation: editorUseTranslate))
        }
        isShowingEditor = false
        loadRules()
    }

    func cancelEdit() {
        isShowingEditor = false
    }
}
