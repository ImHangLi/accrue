import XCTest
@testable import AccrueCore

final class AccrueSnapshotCalculatorTests: XCTestCase {
    func testDefaultWorkdayConfigurationProducesAccruingSnapshot() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let date = try XCTUnwrap(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 5,
            day: 19,
            hour: 13
        ).date)
        let configuration = AccrueConfiguration(
            currencyCode: "USD",
            hourlyRate: 50,
            workStartHour: 9,
            workEndHour: 17,
            workingWeekdays: [3]
        )

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration,
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.state, .accruing)
        XCTAssertEqual(snapshot.accruedAmount, 200)
        XCTAssertEqual(snapshot.currencyCode, "USD")
        XCTAssertEqual(snapshot.formattedAccruedAmount, "$200.00")
    }
}
