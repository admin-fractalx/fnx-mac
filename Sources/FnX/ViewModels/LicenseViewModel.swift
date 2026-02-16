import AppKit
import Combine

final class LicenseViewModel: ObservableObject {
    @Published private(set) var tier: LicenseManager.Tier = .free
    @Published private(set) var remaining: Int = 0
    @Published private(set) var used: Int = 0
    @Published var licenseKey: String = ""
    @Published private(set) var activationMessage: String = ""
    @Published private(set) var isActivating: Bool = false
    @Published private(set) var activationFailed: Bool = false

    let dailyLimit: Int

    static let monthlyCheckoutURL = URL(string: "https://fractalx.lemonsqueezy.com/checkout/buy/4e5e9629-bf4f-4c0f-8158-d63b3ad65efb")!
    static let annualCheckoutURL = URL(string: "https://fractalx.lemonsqueezy.com/checkout/buy/00ec8b3f-0c92-4858-949c-a0eb262d5dec")!

    private let licenseManager: LicenseManager
    private let onUpdate: () -> Void

    var isPro: Bool { tier == .pro }

    var maskedKey: String? {
        guard let key = licenseManager.getLicenseKey() else { return nil }
        return String(key.prefix(8)) + "..." + String(key.suffix(4))
    }

    var usageFraction: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(used) / Double(dailyLimit)
    }

    init(licenseManager: LicenseManager, onUpdate: @escaping () -> Void) {
        self.licenseManager = licenseManager
        self.onUpdate = onUpdate
        self.dailyLimit = licenseManager.dailyLimit
        refresh()
    }

    func refresh() {
        tier = licenseManager.tier
        remaining = licenseManager.remainingToday
        used = dailyLimit - remaining
    }

    func activate() {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            activationMessage = "Please enter a license key."
            activationFailed = true
            return
        }

        isActivating = true
        activationMessage = ""
        activationFailed = false

        Task {
            do {
                try await licenseManager.activate(key: key)
                await MainActor.run {
                    self.isActivating = false
                    self.activationMessage = "License activated!"
                    self.activationFailed = false
                    self.refresh()
                    self.onUpdate()
                }
            } catch {
                await MainActor.run {
                    self.isActivating = false
                    self.activationMessage = error.localizedDescription
                    self.activationFailed = true
                }
            }
        }
    }

    func deactivate() {
        licenseManager.deactivate()
        licenseKey = ""
        activationMessage = ""
        refresh()
        onUpdate()
    }

    func openCheckout(annual: Bool) {
        let url = annual ? Self.annualCheckoutURL : Self.monthlyCheckoutURL
        NSWorkspace.shared.open(url)
    }

    func resetUsage() {
        UserDefaults.standard.set(0, forKey: "fnx_usage_count")
        refresh()
    }
}
