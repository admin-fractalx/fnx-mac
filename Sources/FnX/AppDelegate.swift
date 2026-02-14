import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager!
    private var keyboardMonitor: KeyboardMonitor!
    private var audioRecorder: AudioRecorder!
    private var whisperService: WhisperService!
    private var textInjector: TextInjector!
    private var textProcessor: TextProcessor!
    private var rulesManager: RulesManager!
    private var overlayWindow: OverlayWindow!
    private var settingsWindow: SettingsWindow?
    private var onboardingWindow: OnboardingWindow?
    private var isRecording = false
    private let onboardingKey = "fnx_onboarding_completed"

    func applicationDidFinishLaunching(_ notification: Notification) {
        rulesManager = RulesManager()
        audioRecorder = AudioRecorder()
        whisperService = WhisperService()
        textInjector = TextInjector()
        textProcessor = TextProcessor()
        overlayWindow = OverlayWindow()

        statusBarManager = StatusBarManager(
            rulesManager: rulesManager,
            onSettingsRequested: { [weak self] in self?.openSettings() },
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
        isRecording = true

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

        DispatchQueue.main.async {
            self.statusBarManager.setRecording(false)
            self.overlayWindow.showProcessing()
        }

        let apiKey = Secrets.openAIAPIKey
        guard let audioURL = audioRecorder.lastRecordingURL else {
            DispatchQueue.main.async { self.overlayWindow.hide() }
            return
        }

        Task {
            do {
                let rawText = try await whisperService.transcribe(fileURL: audioURL, apiKey: apiKey)

                let finalText: String
                if let activeRule = rulesManager.activeRule, !activeRule.prompt.isEmpty {
                    finalText = try await textProcessor.process(
                        text: rawText,
                        rulePrompt: activeRule.prompt,
                        apiKey: apiKey
                    )
                } else {
                    finalText = rawText
                }

                await MainActor.run {
                    self.textInjector.type(finalText)
                    self.overlayWindow.showDone()
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
}
