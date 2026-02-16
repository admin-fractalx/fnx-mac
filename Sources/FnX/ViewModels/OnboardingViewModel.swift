import AppKit
import ApplicationServices
import AVFoundation
import Combine
import Foundation

final class OnboardingViewModel: ObservableObject {
    static let totalPages = 5

    @Published var currentPage = 0
    @Published var micGranted = false
    @Published var accessibilityGranted = false
    @Published var tryItStatus = "Hold Fn and speak..."
    @Published var tryItText = ""
    @Published var showTryPlaceholder = true
    @Published var isTryRecording = false

    private let audioRecorder: AudioRecorder
    private let whisperService: WhisperService
    private let onComplete: () -> Void

    private var permissionTimer: Timer?
    private var tryKeyboardMonitor: (Any, Any)?
    private var tryPulseTimer: Timer?

    var canContinueFromPermissions: Bool { micGranted && accessibilityGranted }
    var actionButtonTitle: String {
        if currentPage == 3 {
            return canContinueFromPermissions ? "Continue" : "Grant Permissions"
        }
        if currentPage == Self.totalPages - 1 { return "Get Started" }
        return "Continue"
    }
    var isActionEnabled: Bool {
        if currentPage == 3 { return canContinueFromPermissions }
        return true
    }

    init(audioRecorder: AudioRecorder, whisperService: WhisperService, onComplete: @escaping () -> Void) {
        self.audioRecorder = audioRecorder
        self.whisperService = whisperService
        self.onComplete = onComplete
    }

    deinit {
        permissionTimer?.invalidate()
        tryPulseTimer?.invalidate()
        if let m = tryKeyboardMonitor {
            NSEvent.removeMonitor(m.0)
            NSEvent.removeMonitor(m.1)
        }
    }

    func didShowPage(_ index: Int) {
        if index == 3 {
            refreshPermissions()
            startPermissionPolling()
        } else {
            stopPermissionPolling()
        }
        if index == 4 {
            startTryItMonitor()
        } else {
            stopTryItMonitor()
        }
    }

    func goNext() {
        if currentPage < Self.totalPages - 1 {
            didShowPage(currentPage + 1)
            currentPage += 1
        } else {
            stopTryItMonitor()
            onComplete()
        }
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPermissions() }
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermissions() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(opts)
    }

    private func startPermissionPolling() {
        refreshPermissions()
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
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
        if let m = tryKeyboardMonitor {
            NSEvent.removeMonitor(m.0)
            NSEvent.removeMonitor(m.1)
        }
        tryKeyboardMonitor = nil
        tryPulseTimer?.invalidate()
        tryPulseTimer = nil
    }

    private func handleTryFlagsChanged(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)
        if fnPressed && !isTryRecording {
            startTryRecording()
        } else if !fnPressed && isTryRecording {
            stopTryRecording()
        }
    }

    private func startTryRecording() {
        isTryRecording = true
        tryItStatus = "Listening..."
        do {
            try audioRecorder.startRecording()
        } catch {
            isTryRecording = false
            tryItStatus = "Recording failed. Try again."
        }
    }

    private func stopTryRecording() {
        isTryRecording = false
        audioRecorder.stopRecording()
        tryItStatus = "Processing..."

        guard let audioURL = audioRecorder.lastRecordingURL else {
            tryItStatus = "Hold Fn and speak..."
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await whisperService.transcribe(fileURL: audioURL)
                await MainActor.run {
                    self.showTryPlaceholder = false
                    if !self.tryItText.isEmpty { self.tryItText += "\n" }
                    self.tryItText += text
                    self.tryItStatus = "Done! Try again or continue."
                }
            } catch {
                await MainActor.run {
                    self.tryItStatus = "Error. Hold Fn to retry."
                }
            }
            try? FileManager.default.removeItem(at: audioURL)
        }
    }
}
