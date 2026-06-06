import Foundation

public enum Secrets {
    /// OpenAI API key resolved at runtime in this order:
    ///   1. `OPENAI_API_KEY` environment variable
    ///   2. macOS Keychain (`com.fnx.openai-api-key`, via `KeychainHelper`)
    ///   3. Compile-time fallback from `Secrets+Local.swift` (gitignored)
    ///
    /// See docs/DEVELOPMENT.md for setup. The repo never ships a real key.
    public static var openAIAPIKey: String {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        if let keychain = KeychainHelper.getAPIKey(), !keychain.isEmpty {
            return keychain
        }
        return localFallbackAPIKey
    }
}
