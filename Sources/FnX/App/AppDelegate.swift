import AppKit
import AVFoundation
import FnXUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager!
    private var keyboardMonitor: KeyboardMonitor!
    private var audioRecorder: AudioRecorder!
    private var whisperService: WhisperService!
    private var textInjector: TextInjector!
    private var textProcessor: TextProcessor!
    private var rulesManager: RulesManager!
    private var licenseManager: LicenseManager!
    private var overlayWindow: OverlayWindow!
    private var settingsWindow: SettingsWindow?
    private var licenseWindow: LicenseWindow?
    private var onboardingWindow: OnboardingWindow?
    private var soundEffect: SoundEffect!
    private var isRecording = false
    private let onboardingKey = "fnx_onboarding_completed"

    func applicationDidFinishLaunching(_ notification: Notification) {
        rulesManager = RulesManager()
        licenseManager = LicenseManager()
        audioRecorder = AudioRecorder()
        whisperService = WhisperService()
        textInjector = TextInjector()
        textProcessor = TextProcessor()
        overlayWindow = OverlayWindow()
        soundEffect = SoundEffect()

        statusBarManager = StatusBarManager(
            rulesManager: rulesManager,
            licenseManager: licenseManager,
            onSettingsRequested: { [weak self] in self?.openSettings() },
            onLicenseRequested: { [weak self] in self?.openLicense() },
            onCheckForUpdatesRequested: { [weak self] in self?.checkForUpdates() },
            onQuitRequested: { NSApp.terminate(nil) }
        )

        keyboardMonitor = KeyboardMonitor(
            onRecordingStarted: { [weak self] in self?.startRecording() },
            onRecordingStopped: { [weak self] in self?.stopRecording() }
        )

        if UserDefaults.standard.bool(forKey: onboardingKey) {
            keyboardMonitor.start()
            requestMicrophonePermission()
        } else {
            showOnboarding()
        }

        Task { await licenseManager.validateOnStartup() }
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Microphone Access Required"
                    alert.informativeText = "FnX needs microphone access to transcribe speech. Please enable it in System Settings → Privacy & Security → Microphone."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    private func startRecording() {
        guard !isRecording else { return }

        guard licenseManager.canTranscribe else {
            DispatchQueue.main.async {
                self.overlayWindow.showLimitReached()
                // Auto-open paywall after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.openLicense()
                }
            }
            return
        }

        isRecording = true
        soundEffect.playStartTone()

        DispatchQueue.main.async {
            self.statusBarManager.setRecording(true)
            self.overlayWindow.showRecording()
        }

        do {
            try audioRecorder.startRecording()
        } catch {
            isRecording = false
            DispatchQueue.main.async {
                self.statusBarManager.setRecording(false)
                self.overlayWindow.hide()
            }
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioRecorder.stopRecording()
        soundEffect.playStopTone()

        DispatchQueue.main.async {
            self.statusBarManager.setRecording(false)
            self.overlayWindow.showProcessing()
        }

        guard let audioURL = audioRecorder.lastRecordingURL else {
            DispatchQueue.main.async { self.overlayWindow.hide() }
            return
        }

        Task {
            do {
                let finalText: String

                if let activeRule = rulesManager.activeRule {
                    if activeRule.useTranslation {
                        finalText = try await whisperService.transcribe(fileURL: audioURL, translate: true)
                    } else if !activeRule.prompt.isEmpty {
                        let rawText = try await whisperService.transcribe(fileURL: audioURL)
                        let apiKey = Secrets.openAIAPIKey
                        finalText = try await textProcessor.process(
                            text: rawText,
                            rulePrompt: activeRule.prompt,
                            apiKey: apiKey
                        )
                    } else {
                        finalText = try await whisperService.transcribe(fileURL: audioURL)
                    }
                } else {
                    finalText = try await whisperService.transcribe(fileURL: audioURL)
                }

                guard Self.isUsableTranscription(finalText) else {
                    await MainActor.run {
                        self.overlayWindow.hide()
                    }
                    try? FileManager.default.removeItem(at: audioURL)
                    return
                }

                await MainActor.run {
                    self.textInjector.type(finalText)
                    self.overlayWindow.showDone()
                }

                licenseManager.incrementUsage()
                await MainActor.run {
                    self.statusBarManager.setupMenu()
                    self.licenseWindow?.refreshState()
                }
            } catch {
                await MainActor.run {
                    self.overlayWindow.hide()
                    print("Transcription error: \(error)")
                }
            }

            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    private func showOnboarding() {
        onboardingWindow = OnboardingWindow(
            audioRecorder: audioRecorder,
            whisperService: whisperService
        ) { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: self.onboardingKey)
            self.onboardingWindow = nil
            NSApp.setActivationPolicy(.accessory)
            self.keyboardMonitor.start()
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.showWithAnimation()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(rulesManager: rulesManager)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Returns false if Whisper output is empty, too short, or a known hallucination pattern.
    private static func isUsableTranscription(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or too short to be real speech
        if trimmed.count < 2 { return false }

        let lowered = trimmed.lowercased()

        // Whisper hallucination patterns for silence / bad audio
        let junkPatterns = [
            "[blank_audio]",
            "(blank audio)",
            "[silence]",
            "(silence)",
            "[inaudible]",
            "(inaudible)",
            "[music]",
            "(music)",
            "you",
            "thank you.",
            "thanks for watching.",
            "thank you for watching.",
            "thanks for watching!",
            "subscribe",
            "please subscribe",
            "...",
            "♪",
        ]

        for pattern in junkPatterns {
            if lowered == pattern || lowered == "[\(pattern)]" || lowered == "(\(pattern))" {
                return false
            }
        }

        // Detect bracket/paren-wrapped junk like [MUSIC], (BLANK), etc.
        if let _ = trimmed.range(of: #"^[\[\(].*[\]\)]$"#, options: .regularExpression),
           trimmed.count < 30 {
            return false
        }

        // Single repeated character (e.g. "aaaaaaa" or "......")
        let uniqueChars = Set(trimmed.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
        if uniqueChars.count <= 1 { return false }

        return true
    }

    private func checkForUpdates() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        Task {
            do {
                let url = URL(string: "https://api.github.com/repos/admin-fractalx/fnx-mac/releases/latest")!
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: request)

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    await MainActor.run { self.showUpdateAlert(message: "Could not check for updates. Please try again later.") }
                    return
                }

                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                await MainActor.run {
                    if latestVersion > currentVersion {
                        let alert = NSAlert()
                        alert.messageText = "Update Available"
                        alert.informativeText = "FnX v\(latestVersion) is available. You're currently on v\(currentVersion)."
                        alert.addButton(withTitle: "Download")
                        alert.addButton(withTitle: "Later")
                        alert.alertStyle = .informational
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn, let releaseURL = URL(string: htmlURL) {
                            NSWorkspace.shared.open(releaseURL)
                        }
                    } else {
                        self.showUpdateAlert(message: "You're up to date! FnX v\(currentVersion) is the latest version.")
                    }
                }
            } catch {
                await MainActor.run {
                    self.showUpdateAlert(message: "Could not check for updates. Please try again later.")
                }
            }
        }
    }

    private func showUpdateAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func openLicense() {
        if licenseWindow == nil {
            licenseWindow = LicenseWindow(licenseManager: licenseManager) { [weak self] in
                self?.statusBarManager.setupMenu()
            }
        }
        licenseWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
