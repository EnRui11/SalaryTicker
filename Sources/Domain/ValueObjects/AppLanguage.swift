import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case malay = "ms"

    /// Each language names itself, so the picker is readable whichever one is active.
    public var displayName: String {
        switch self {
        case .english: "English"
        case .chinese: "简体中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .malay: "Bahasa Melayu"
        }
    }

    /// Whether the currency symbol conventionally comes before the amount.
    ///
    /// Romance and Germanic European conventions put it after ("134,01 $"); the rest of
    /// the set puts it first. Portuguese follows the Brazilian form ("R$ 134,01").
    public var currencySymbolLeads: Bool {
        switch self {
        case .spanish, .french, .german: false
        case .english, .chinese, .japanese, .korean, .portuguese, .malay: true
        }
    }

    /// Drives `DatePicker` and other system-formatted controls.
    public var localeIdentifier: String {
        switch self {
        case .english: "en"
        case .chinese: "zh-Hans"
        case .japanese: "ja"
        case .korean: "ko"
        case .spanish: "es"
        case .french: "fr"
        case .german: "de"
        case .portuguese: "pt"
        case .malay: "ms"
        }
    }
}
