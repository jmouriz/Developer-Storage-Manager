import Foundation

enum L10n {
    static var availableLocalizations: [String] { Bundle.module.localizations }

    static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: .current, arguments: arguments)
    }

    static func plural(one: String, other: String, count: Int) -> String {
        format(count == 1 ? one : other, count)
    }
}
