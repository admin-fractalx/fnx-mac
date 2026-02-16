import Foundation
import Security

public final class LicenseManager {
    public enum Tier: String {
        case free, pro
    }

    public enum LicenseError: Error, LocalizedError {
        case invalidKey
        case networkError
        case serverError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidKey: return "Invalid license key"
            case .networkError: return "Network error. Check your connection."
            case .serverError(let msg): return msg
            }
        }
    }

    private let keychainService = "com.fnx.license-key"
    private let keychainAccount = "license"
    private let tierKey = "fnx_license_tier"
    private let usageDateKey = "fnx_usage_date"
    private let usageCountKey = "fnx_usage_count"

    public let dailyLimit = 15

    public private(set) var tier: Tier {
        didSet {
            UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
        }
    }

    public var canTranscribe: Bool {
        tier == .pro || dailyUsage < dailyLimit
    }

    public var canUseRules: Bool {
        tier == .pro
    }

    public var remainingToday: Int {
        tier == .pro ? .max : max(0, dailyLimit - dailyUsage)
    }

    public private(set) var dailyUsage: Int {
        get {
            resetIfNewDay()
            return UserDefaults.standard.integer(forKey: usageCountKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: usageCountKey)
        }
    }

    public init() {
        let cached = UserDefaults.standard.string(forKey: tierKey) ?? "free"
        self.tier = Tier(rawValue: cached) ?? .free
    }

    public func incrementUsage() {
        resetIfNewDay()
        let current = UserDefaults.standard.integer(forKey: usageCountKey)
        UserDefaults.standard.set(current + 1, forKey: usageCountKey)
    }

    private func resetIfNewDay() {
        let today = todayString()
        let stored = UserDefaults.standard.string(forKey: usageDateKey)
        if stored != today {
            UserDefaults.standard.set(today, forKey: usageDateKey)
            UserDefaults.standard.set(0, forKey: usageCountKey)
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    public func activate(key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LicenseError.invalidKey }

        let instanceName = "FnX-\(machineID())"

        let activated = try await lemonSqueezyRequest(
            endpoint: "https://api.lemonsqueezy.com/v1/licenses/activate",
            licenseKey: trimmed,
            instanceName: instanceName
        )

        guard activated else { throw LicenseError.invalidKey }

        saveLicenseKey(trimmed)
        tier = .pro
    }

    public func deactivate() {
        if let key = getLicenseKey() {
            let instanceName = "FnX-\(machineID())"
            Task {
                _ = try? await lemonSqueezyRequest(
                    endpoint: "https://api.lemonsqueezy.com/v1/licenses/deactivate",
                    licenseKey: key,
                    instanceName: instanceName
                )
            }
        }
        deleteLicenseKey()
        tier = .free
    }

    public func validateOnStartup() async {
        guard let key = getLicenseKey() else {
            tier = .free
            return
        }

        let instanceName = "FnX-\(machineID())"
        let valid = (try? await lemonSqueezyRequest(
            endpoint: "https://api.lemonsqueezy.com/v1/licenses/validate",
            licenseKey: key,
            instanceName: instanceName
        )) ?? false

        if !valid && tier == .pro {
        }
    }

    private func lemonSqueezyRequest(
        endpoint: String,
        licenseKey: String,
        instanceName: String
    ) async throws -> Bool {
        guard let url = URL(string: endpoint) else {
            throw LicenseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = "license_key=\(licenseKey)&instance_name=\(instanceName)"
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError
        }

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let valid = json["valid"] as? Bool {
                    return valid
                }
                if let activated = json["activated"] as? Bool {
                    return activated
                }
            }
            return true
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw LicenseError.serverError(error)
            }
            return false
        }

        throw LicenseError.networkError
    }

    private func machineID() -> String {
        if let existing = UserDefaults.standard.string(forKey: "fnx_machine_id") {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "fnx_machine_id")
        return id
    }

    public var hasLicenseKey: Bool {
        getLicenseKey() != nil
    }

    public func getLicenseKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveLicenseKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func deleteLicenseKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
