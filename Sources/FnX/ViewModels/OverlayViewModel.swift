import Combine
import Foundation

enum OverlayState: Equatable {
    case hidden
    case recording
    case processing
    case done
    case limitReached
    case proRequired
}

final class OverlayViewModel: ObservableObject {
    @Published private(set) var state: OverlayState = .hidden
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var contentVisible: Bool = false
    @Published var label: String = ""

    private var contentTimer: Timer?

    func showRecording() {
        state = .recording
        label = "Listening..."
        appear()
    }

    func showProcessing() {
        state = .processing
        label = "Processing..."
        // Already visible — show content immediately for state transitions
        if isVisible {
            contentVisible = true
        } else {
            appear()
        }
    }

    func showDone() {
        state = .done
        label = "Done!"
        if isVisible {
            contentVisible = true
        } else {
            appear()
        }
    }

    func showLimitReached() {
        state = .limitReached
        label = "Daily limit reached"
        appear()
    }

    func showProRequired() {
        state = .proRequired
        label = "Pro required for AI Rules"
        appear()
    }

    func hide() {
        contentTimer?.invalidate()
        contentVisible = false
        // Small delay so content fades out before the shape retracts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.isVisible = false
            self?.state = .hidden
        }
    }

    private func appear() {
        contentTimer?.invalidate()
        isVisible = true
        contentVisible = false
        // Show content after the black shape has expanded
        contentTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.contentVisible = true
        }
    }
}
