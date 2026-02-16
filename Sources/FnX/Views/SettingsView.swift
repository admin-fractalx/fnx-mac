import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var searchText = ""

    private var filteredRules: [Rule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.rules }
        return viewModel.rules.filter { rule in
            rule.name.localizedCaseInsensitiveContains(query) ||
            rule.prompt.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.9),
                    Color.accentColor.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                header

                HStack(spacing: 14) {
                    rulesPanel
                    detailsPanel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(18)
        }
        .frame(width: 560, height: 390)
        .sheet(isPresented: $viewModel.isShowingEditor) {
            RuleEditorSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules")
                    .font(.system(size: 23, weight: .bold))
                Text("Customize how dictated text gets transformed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.addRule()
            } label: {
                Label("New Rule", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var rulesPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search rules", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

            if filteredRules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("No rules found")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRules) { rule in
                            RuleRow(
                                rule: rule,
                                isSelected: viewModel.selectedRuleID == rule.id
                            )
                            .onTapGesture {
                                viewModel.selectedRuleID = rule.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .frame(width: 250)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
        )
    }

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedRule = viewModel.selectedRule {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedRule.name)
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    RuleKindBadge(isOffline: selectedRule.useWhisperTranslate)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if selectedRule.isDefault {
                        defaultRuleDescription(for: selectedRule)
                    } else {
                        Text("Prompt")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if selectedRule.useWhisperTranslate {
                            Text("This rule uses offline Whisper translation to English.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else if selectedRule.prompt.isEmpty {
                            Text("No prompt configured")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                Text(selectedRule.prompt)
                                    .font(.system(size: 12))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    if viewModel.canEditSelected {
                        Button("Edit Rule") {
                            viewModel.editSelected()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Delete") {
                            viewModel.deleteSelected()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Built-in rule")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Select a rule")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Choose a rule from the left to inspect or edit it.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
        )
    }
}

@ViewBuilder
private func defaultRuleDescription(for rule: Rule) -> some View {
    let descriptions: [String: (desc: String, details: [String])] = [
        "🌐 Translate to English": (
            "Translates speech from any language to English using offline Whisper.",
            ["Works offline — no internet needed", "Supports 90+ languages", "Real-time translation during transcription"]
        ),
        "✏️ Clean English": (
            "Cleans up dictated text and outputs polished English.",
            ["Speaks any language → outputs English", "Fixes grammar, spelling & punctuation", "Removes filler words (um, uh, like...)", "Handles messy speech-to-text errors"]
        ),
        "✏️ Clean Spanish": (
            "Cleans up dictated text and outputs polished Spanish.",
            ["Speaks any language → outputs Spanish", "Fixes grammar, spelling & punctuation", "Removes filler words (este, bueno, o sea...)", "Handles messy speech-to-text errors"]
        ),
        "🧠 Prompt Builder": (
            "Turns your spoken idea into a clear AI prompt in English.",
            ["Describe what you want in any language", "Outputs a well-structured LLM prompt", "Adds constraints & output format if implied", "Great for ChatGPT, Claude, etc."]
        ),
        "📧 Professional Email": (
            "Turns your spoken thoughts into a professional email in English.",
            ["Speak casually in any language", "Follows a clean template: greeting → context → body → closing", "Matches implied formality level", "Keeps emails short (4-8 lines max)"]
        ),
    ]

    let info = descriptions[rule.name]

    VStack(alignment: .leading, spacing: 10) {
        Text(info?.desc ?? "Built-in rule.")
            .font(.system(size: 12))
            .foregroundStyle(.primary)

        if let details = info?.details {
            ForEach(details, id: \.self) { detail in
                Label(detail, systemImage: "checkmark")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RuleRow: View {
    let rule: Rule
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(rule.useWhisperTranslate ? "Translate to English offline" : rule.prompt)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
            }

            Spacer(minLength: 8)

            if rule.isDefault {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.5))
            }

            RuleKindBadge(isOffline: rule.useWhisperTranslate, compact: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct RuleKindBadge: View {
    let isOffline: Bool
    var compact = false

    var body: some View {
        Text(isOffline ? "Offline" : "AI")
            .font(.system(size: compact ? 10 : 11, weight: .bold))
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 4 : 5)
            .foregroundStyle(isOffline ? .green : .orange)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .fill((isOffline ? Color.green : Color.orange).opacity(0.12))
            )
    }
}

private struct RuleEditorSheet: View {
    @ObservedObject var viewModel: SettingsViewModel

    private var canSave: Bool {
        !viewModel.editorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (viewModel.editorUseTranslate || !viewModel.editorPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.editingRule == nil ? "New Rule" : "Edit Rule")
                .font(.system(size: 18, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .semibold))
                TextField("Name", text: $viewModel.editorName)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Use offline Whisper translation to English", isOn: $viewModel.editorUseTranslate)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text("AI Prompt")
                    .font(.system(size: 12, weight: .semibold))
                TextEditor(text: $viewModel.editorPrompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .disabled(viewModel.editorUseTranslate)
                    .opacity(viewModel.editorUseTranslate ? 0.5 : 1)

                Text("Ignored when offline translation is enabled.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { viewModel.cancelEdit() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { viewModel.saveRule() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 430, height: 360)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel(rulesManager: .init()))
    }
}
#endif
