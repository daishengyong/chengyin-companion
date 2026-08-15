import Foundation

enum CompanionLocalization {
    private static let bundle: Bundle = {
        // Transactional `.app` packaging places .lproj directories in the main
        // bundle. SwiftPM development uses its generated resource bundle.
        if Bundle.main.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: "en"
        ) != nil {
            return Bundle.main
        }
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle.main
#endif
    }()

    static func string(key: String, fallback: String) -> String {
        bundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    static func format(
        key: String,
        fallback: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key: key, fallback: fallback),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
