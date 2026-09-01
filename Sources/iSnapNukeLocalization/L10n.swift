import Foundation

public enum iSnapNukeLanguage: Equatable, Sendable {
    case english
    case traditionalChinese

    public static func resolve(localeIdentifier: String) -> iSnapNukeLanguage {
        let normalized = localeIdentifier.replacingOccurrences(of: "_", with: "-").lowercased()
        let isTraditionalChinese =
            normalized == "zh-hant" ||
            normalized.hasPrefix("zh-hant-") ||
            normalized == "zh-tw" ||
            normalized.hasPrefix("zh-tw-") ||
            normalized == "zh-hk" ||
            normalized.hasPrefix("zh-hk-") ||
            normalized == "zh-mo" ||
            normalized.hasPrefix("zh-mo-")

        return isTraditionalChinese ? .traditionalChinese : .english
    }

    var localizationCode: String {
        switch self {
        case .english: "en"
        case .traditionalChinese: "zh-Hant"
        }
    }
}

public enum L10n {
    public static var currentLanguage: iSnapNukeLanguage {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        return iSnapNukeLanguage.resolve(localeIdentifier: preferredIdentifier)
    }

    public static func text(
        _ key: String,
        language: iSnapNukeLanguage = currentLanguage
    ) -> String {
        let localizedBundle = bundle(for: language)
        return localizedBundle.localizedString(forKey: key, value: englishFallback(for: key), table: "Localizable")
    }

    public static func format(
        _ key: String,
        _ arguments: CVarArg...,
        language: iSnapNukeLanguage = currentLanguage
    ) -> String {
        let locale = Locale(identifier: language.localizationCode)
        return String(
            format: text(key, language: language),
            locale: locale,
            arguments: arguments
        )
    }

    public static func byteCount(
        _ bytes: Int64?,
        language: iSnapNukeLanguage = currentLanguage
    ) -> String {
        guard let bytes, bytes >= 0 else {
            return text("size.unavailable", language: language)
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.isAdaptive = true
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }

    public static func time(
        _ date: Date,
        language: iSnapNukeLanguage = currentLanguage
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localizationCode)
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private static func bundle(for language: iSnapNukeLanguage) -> Bundle {
        for resourceCode in language.resourceCodes {
            if
                let localizedPath = resourceBundle.path(forResource: resourceCode, ofType: "lproj"),
                let localizedBundle = Bundle(path: localizedPath)
            {
                return localizedBundle
            }
        }
        return resourceBundle
}

    private static func englishFallback(for key: String) -> String {
        let englishPath = resourceBundle.path(forResource: "en", ofType: "lproj")
        let englishBundle = englishPath.flatMap(Bundle.init(path:))
        return englishBundle?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
    }

    private static let resourceBundle: Bundle = {
        if
            let resourceURL = Bundle.main.resourceURL,
            let bundle = Bundle(url: resourceURL.appendingPathComponent("iSnapNuke_iSnapNukeLocalization.bundle"))
        {
            return bundle
        }
        return Bundle.module
    }()
}

private extension iSnapNukeLanguage {
    var resourceCodes: [String] {
        switch self {
        case .english:
            ["en"]
        case .traditionalChinese:
            ["zh-Hant", "zh-hant"]
        }
    }
}
