import Foundation

public struct Rule: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var prompt: String
    public var useTranslation: Bool
    public var isDefault: Bool

    public init(id: UUID = UUID(), name: String, prompt: String, useTranslation: Bool = false, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.useTranslation = useTranslation
        self.isDefault = isDefault
    }
}

public final class RulesManager {
    private let rulesKey = "fnx_rules"
    private let activeRuleIDKey = "fnx_active_rule_id"
    private let rulesVersionKey = "fnx_rules_version"
    private let currentVersion = 7 // Bump this when defaults change

    public init() {
        migrateIfNeeded()
    }

    private func migrateIfNeeded() {
        let saved = UserDefaults.standard.integer(forKey: rulesVersionKey)
        if saved < currentVersion {
            // Clear old defaults so they reload
            UserDefaults.standard.removeObject(forKey: rulesKey)
            UserDefaults.standard.set(currentVersion, forKey: rulesVersionKey)
        }
    }
    
    public var rules: [Rule] {
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
    
    public var activeRuleID: UUID? {
        get {
            guard let string = UserDefaults.standard.string(forKey: activeRuleIDKey) else { return nil }
            return UUID(uuidString: string)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: activeRuleIDKey)
        }
    }
    
    public var activeRule: Rule? {
        guard let id = activeRuleID else { return nil }
        return rules.first { $0.id == id }
    }
    
    public func addRule(_ rule: Rule) {
        var current = rules
        current.append(rule)
        rules = current
    }
    
    public func updateRule(_ rule: Rule) {
        var current = rules
        if let index = current.firstIndex(where: { $0.id == rule.id }) {
            current[index] = rule
            rules = current
        }
    }
    
    public func deleteRule(id: UUID) {
        var current = rules
        current.removeAll { $0.id == id }
        rules = current
        if activeRuleID == id {
            activeRuleID = nil
        }
    }
    
    private var defaultRules: [Rule] {
        let defaults = [
            Rule(
                name: "🌐 Translate to English",
                prompt: "",
                useTranslation: true,
                isDefault: true
            ),

            Rule(
                name: "✏️ Clean English",
                prompt: """
                You receive raw speech-to-text output that may contain mishearings, \
                filler words (um, uh, like, eh, este, bueno), repetitions, false starts, \
                or mixed-language fragments. The speaker may be talking in ANY language. \
                Your job: \
                1) Infer the speaker's intended meaning even if words are garbled or misspelled. \
                2) Translate to English if the input is not already in English. \
                3) Fix grammar, spelling, punctuation, and capitalization. \
                4) Remove filler words and false starts. Keep the original tone and intent. \
                Return ONLY the clean English text. No explanations, no quotes.
                """,
                isDefault: true
            ),

            Rule(
                name: "✏️ Clean Spanish",
                prompt: """
                You receive raw speech-to-text output that may contain mishearings, \
                filler words (um, uh, like, eh, este, bueno, o sea), repetitions, false starts, \
                or mixed-language fragments. The speaker may be talking in ANY language. \
                Your job: \
                1) Infer the speaker's intended meaning even if words are garbled or misspelled. \
                2) Translate to Spanish if the input is not already in Spanish. \
                3) Fix grammar, spelling, punctuation, and capitalization. \
                4) Remove filler words and false starts. Keep the original tone and intent. \
                Return ONLY the clean Spanish text. No explanations, no quotes.
                """,
                isDefault: true
            ),

            Rule(
                name: "🧠 Prompt Builder",
                prompt: """
                You receive raw speech-to-text output from a user describing what they want an AI to do. \
                The input may be in ANY language and may contain mishearings, filler words, \
                repetitions, or incomplete sentences. \
                Your job: \
                1) Infer the user's true intent even if the transcription is messy. \
                2) Rewrite it as a clear, specific, high-quality prompt in English. \
                3) Make the task explicit. Add constraints or output format if implied. \
                4) Keep it concise — no fluff, no meta-commentary. \
                Return ONLY the final prompt. No explanations, no quotes, no preamble.
                """,
                isDefault: true
            ),

            Rule(
                name: "📧 Professional Email",
                prompt: """
                You receive raw speech-to-text output from a user describing what they want to communicate via email. \
                The input may be in ANY language and may contain mishearings, filler words, \
                repetitions, or rambling thoughts. \
                Your job: \
                1) Infer what the user actually wants to say even if the transcription is messy. \
                2) Write a concise, professional email body in English following this structure: \
                \
                --- Template --- \
                Hi [Name / Team], \
                \
                [Opening line: context or reason for writing — 1 sentence] \
                \
                [Body: key message, details, or request — 2-4 sentences max] \
                \
                [Closing line: next step, call to action, or courtesy — 1 sentence] \
                \
                Best regards, \
                [Leave blank for the user to fill] \
                --- End Template --- \
                \
                3) Match the implied formality level. Use "Dear" for formal, "Hi/Hey" for casual. \
                4) Remove any filler, repetition, or off-topic tangents. \
                5) Keep it short. Most professional emails should be 4-8 lines max. \
                Return ONLY the email text. No subject line, no explanations, no quotes.
                """,
                isDefault: true
            ),
        ]
        if let data = try? JSONEncoder().encode(defaults) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
        return defaults
    }
}
