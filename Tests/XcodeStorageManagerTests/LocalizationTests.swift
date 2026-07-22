import Testing
@testable import XcodeStorageManager

@Test func allSupportedLocalizationsAreBundled() {
    let available = Set(L10n.availableLocalizations)
    #expect(available.isSuperset(of: ["en", "es", "pt", "fr"]))
}
