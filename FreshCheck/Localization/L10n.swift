import Foundation

enum L10n {
    static let appLanguageStorageKey = "app_language"

    static func tr(_ key: String) -> String {
        let bundle = bundleForCurrentAppLanguage()
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    // Keep backend language contract simple.
    static var aiLanguageCode: String {
        let appLanguage = currentAppLanguage()
        switch appLanguage {
        case .chineseSimplified:
            return "zh"
        case .english:
            return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("zh") ? "zh" : "en"
        }
    }

    static func localeForAppLanguage() -> Locale {
        Locale(identifier: currentAppLanguage().localeIdentifier)
    }

    private static func currentAppLanguage() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: appLanguageStorageKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    private static func bundleForCurrentAppLanguage() -> Bundle {
        let selected = currentAppLanguage()
        let languageCode: String
        switch selected {
        case .system:
            languageCode = Locale.preferredLanguages.first ?? "en"
        case .english:
            languageCode = "en"
        case .chineseSimplified:
            languageCode = "zh-Hans"
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let fallback = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: fallback) {
            return bundle
        }

        return .main
    }
}
