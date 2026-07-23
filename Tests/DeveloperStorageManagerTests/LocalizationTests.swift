import Testing
@testable import DeveloperStorageManager

@Test func allSupportedLocalizationsAreBundled() {
    let available = Set(L10n.availableLocalizations)
    #expect(available.isSuperset(of: ["en", "es", "pt", "fr"]))
}
