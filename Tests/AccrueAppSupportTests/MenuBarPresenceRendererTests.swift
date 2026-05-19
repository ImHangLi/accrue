import AccrueAppSupport
import AccrueCore
import XCTest

final class MenuBarPresenceRendererTests: XCTestCase {
    func testCalmModeIsDefault() {
        let snapshot = AccrueSnapshot(
            state: .accruing,
            accruedAmount: 200,
            currencyCode: "USD",
            formattedAccruedAmount: "$200.00",
            derivedHourlyRate: 50,
            nextTransition: nil
        )

        let display = MenuBarPresenceRenderer().display(
            for: snapshot,
            preferences: MenuBarDisplayPreferences(),
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(display, .amount("$200.00"))
    }

    func testStealthModeTakesPrecedenceOverRateMode() {
        let snapshot = AccrueSnapshot(
            state: .accruing,
            accruedAmount: 200,
            currencyCode: "USD",
            formattedAccruedAmount: "$200.00",
            derivedHourlyRate: 50,
            nextTransition: nil
        )

        let display = MenuBarPresenceRenderer().display(
            for: snapshot,
            preferences: MenuBarDisplayPreferences(displayMode: .rate, stealthModeEnabled: true),
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(display, .symbol("banknote"))
    }

    func testPopoverCanStillUseSnapshotAmountWhenStealthModeIsEnabled() {
        let snapshot = AccrueSnapshot(
            state: .accruing,
            accruedAmount: 200,
            currencyCode: "USD",
            formattedAccruedAmount: "$200.00",
            derivedHourlyRate: 50,
            nextTransition: nil
        )

        XCTAssertEqual(snapshot.formattedAccruedAmount, "$200.00")
    }

    func testRateModeAddsHourlyRateWhenStealthModeIsOff() {
        let snapshot = AccrueSnapshot(
            state: .accruing,
            accruedAmount: 200,
            currencyCode: "USD",
            formattedAccruedAmount: "$200.00",
            derivedHourlyRate: 50,
            nextTransition: nil
        )

        let display = MenuBarPresenceRenderer().display(
            for: snapshot,
            preferences: MenuBarDisplayPreferences(displayMode: .rate, stealthModeEnabled: false),
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(display, .amountWithRate(amount: "$200.00", hourlyRate: "$50.00/h"))
    }
}
