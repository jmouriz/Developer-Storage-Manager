import Testing
@testable import DeveloperStorageManager

@Test func allSupportedLocalizationsAreBundled() {
    let available = Set(L10n.availableLocalizations)
    #expect(available.isSuperset(of: ["en", "es", "pt", "fr"]))
}

@Test func cleanupResultUsesSingularAndPluralForms() {
    let singular = L10n.plural(
        one: "cleanup.success.simulator.one",
        other: "cleanup.success.simulator.other",
        count: 1
    )
    let plural = L10n.plural(
        one: "cleanup.success.simulator.one",
        other: "cleanup.success.simulator.other",
        count: 2
    )

    #expect(singular.contains("1"))
    #expect(plural.contains("2"))
    #expect(singular != plural)
}
