import Foundation

struct Rule: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var prompt: String

    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}

final class RulesManager {
    private let rulesKey = "fnx_rules"
    private let activeRuleIDKey = "fnx_active_rule_id"

    var rules: [Rule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: rulesKey),
                  let decoded = try? JSONDecoder().decode([Rule].self, from: data) else {
                return defaultRules
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: rulesKey)
            }
        }
    }

    var activeRuleID: UUID? {
        get {
            guard let string = UserDefaults.standard.string(forKey: activeRuleIDKey) else { return nil }
            return UUID(uuidString: string)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: activeRuleIDKey)
        }
    }

    var activeRule: Rule? {
        guard let id = activeRuleID else { return nil }
        return rules.first { $0.id == id }
    }

    func addRule(_ rule: Rule) {
        var current = rules
        current.append(rule)
        rules = current
    }

    func updateRule(_ rule: Rule) {
        var current = rules
        if let index = current.firstIndex(where: { $0.id == rule.id }) {
            current[index] = rule
            rules = current
        }
    }

    func deleteRule(id: UUID) {
        var current = rules
        current.removeAll { $0.id == id }
        rules = current
        if activeRuleID == id {
            activeRuleID = nil
        }
    }

    private var defaultRules: [Rule] {
        let defaults = [
            Rule(name: "Clean Spanish", prompt: "Corrige la gramática y puntuación de este texto dictado. Devuelve solo el texto corregido."),
            Rule(name: "To English", prompt: "Translate this dictated text to proper English. Return only the translated text."),
            Rule(name: "Code Comment", prompt: "Rewrite this as a concise code comment in English. Return only the comment text without // prefix."),
        ]
        // Save defaults on first access
        if let data = try? JSONEncoder().encode(defaults) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
        return defaults
    }
}
