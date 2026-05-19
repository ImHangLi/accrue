import AccrueAppSupport
import AccrueCore
import SwiftData
import XCTest

final class StoredAccrueConfigurationTests: XCTestCase {
    func testStoredConfigurationMapsToCoreConfigurationWithoutPersistingAccruedAmount() {
        let stored = StoredAccrueConfiguration(
            currencyCode: "EUR",
            payRuleKind: .monthlySalary,
            payAmount: 8_000,
            workStartHour: 9,
            workEndHour: 17,
            workingWeekdays: [2, 3, 4, 5, 6]
        )

        let configuration = stored.toCoreConfiguration()

        XCTAssertEqual(configuration.currencyCode, "EUR")
        XCTAssertEqual(configuration.workStartHour, 9)
        XCTAssertEqual(configuration.workEndHour, 17)
        XCTAssertEqual(configuration.workingWeekdays, [2, 3, 4, 5, 6])

        switch configuration.payRule {
        case .monthlySalary(let amount):
            XCTAssertEqual(amount, 8_000)
        case .hourlyRate, .annualSalary:
            XCTFail("Expected Monthly Salary Pay Rule")
        }
    }

    func testSetupDraftUpdatesOnlyConfigurationAndDevicePreferenceFields() {
        let stored = StoredAccrueConfiguration()
        let draft = AccrueSetupDraft(
            currencyCode: "USD",
            payRuleKind: .annualSalary,
            payAmount: 120_000
        )

        stored.apply(draft)

        XCTAssertEqual(stored.currencyCode, "USD")
        XCTAssertEqual(stored.payRuleKind, .annualSalary)
        XCTAssertEqual(stored.payAmount, 120_000)
        XCTAssertEqual(stored.workStartHour, 9)
        XCTAssertEqual(stored.workEndHour, 17)
        XCTAssertEqual(stored.workingWeekdays, [2, 3, 4, 5, 6])
    }

    @MainActor
    func testConfigurationStoreSavesAndRestoresCoreConfiguration() throws {
        let container = try ModelContainer(
            for: StoredAccrueConfiguration.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = try AccrueConfigurationStore(container: container)
        let draft = AccrueSetupDraft(
            currencyCode: "GBP",
            payRuleKind: .hourlyRate,
            payAmount: 60
        )

        try store.save(draft)
        let restoredStore = try AccrueConfigurationStore(container: container)

        XCTAssertEqual(restoredStore.configuration?.currencyCode, "GBP")
        XCTAssertEqual(restoredStore.configuration?.workStartHour, 9)
        XCTAssertEqual(restoredStore.configuration?.workEndHour, 17)
        XCTAssertEqual(restoredStore.configuration?.workingWeekdays, [2, 3, 4, 5, 6])

        switch restoredStore.configuration?.payRule {
        case .hourlyRate(let amount):
            XCTAssertEqual(amount, 60)
        case .monthlySalary, .annualSalary, nil:
            XCTFail("Expected Hourly Rate Pay Rule")
        }
    }
}
