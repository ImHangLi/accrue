import XCTest
@testable import AccrueCore

final class AccrueSnapshotCalculatorTests: XCTestCase {
    func testWorkingDayBeforeWorkStartReturnsWaitingStateWithoutVisibleZeroAmount() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 8, calendar: calendar)
        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.state, .waiting)
        XCTAssertFalse(snapshot.showsAccruedAmount)
        XCTAssertNil(snapshot.accruedAmount)
        XCTAssertNil(snapshot.formattedAccruedAmount)
        XCTAssertEqual(
            snapshot.nextTransition?.date,
            try self.date(year: 2026, month: 5, day: 19, hour: 9, calendar: calendar)
        )
        XCTAssertEqual(snapshot.nextTransition?.state, .accruing)
    }

    func testWorkingDayDuringWorkingHoursReturnsAccruingStateWithElapsedAccruedAmount() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 13, calendar: calendar)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.state, .accruing)
        XCTAssertEqual(snapshot.accruedAmount, 200)
        XCTAssertEqual(snapshot.derivedHourlyRate, 50)
        XCTAssertEqual(snapshot.currencyCode, "USD")
        XCTAssertEqual(snapshot.formattedAccruedAmount, "$200.00")
        XCTAssertEqual(
            snapshot.nextTransition?.date,
            try self.date(year: 2026, month: 5, day: 19, hour: 17, calendar: calendar)
        )
        XCTAssertEqual(snapshot.nextTransition?.state, .done)
    }

    func testWorkingDayAfterWorkingHoursReturnsDoneStateWithFinalDayAccruedAmount() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 18, calendar: calendar)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(workingWeekdays: [3, 4]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.state, .done)
        XCTAssertEqual(snapshot.accruedAmount, 400)
        XCTAssertEqual(snapshot.formattedAccruedAmount, "$400.00")
        XCTAssertEqual(
            snapshot.nextTransition?.date,
            try self.date(year: 2026, month: 5, day: 20, hour: 9, calendar: calendar)
        )
        XCTAssertEqual(snapshot.nextTransition?.state, .accruing)
    }

    func testRestStateDayDoesNotExposeFailureLookingZeroAmount() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 17, hour: 13, calendar: calendar)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(workingWeekdays: [2, 3, 4, 5, 6]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.state, .rest)
        XCTAssertFalse(snapshot.showsAccruedAmount)
        XCTAssertNil(snapshot.accruedAmount)
        XCTAssertNil(snapshot.formattedAccruedAmount)
        XCTAssertEqual(
            snapshot.nextTransition?.date,
            try self.date(year: 2026, month: 5, day: 18, hour: 9, calendar: calendar)
        )
        XCTAssertEqual(snapshot.nextTransition?.state, .accruing)
    }

    func testReopeningAfterElapsedWorkingHoursUsesCurrentWorkdayElapsedTime() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 15, calendar: calendar)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.state, .accruing)
        XCTAssertEqual(snapshot.accruedAmount, 300)
        XCTAssertEqual(snapshot.formattedAccruedAmount, "$300.00")
    }

    func testHourlyRatePayRuleProducesExpectedDerivedHourlyRate() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 13, calendar: calendar)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(payRule: .hourlyRate(75), workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.derivedHourlyRate, 75)
        XCTAssertEqual(snapshot.accruedAmount, 300)
    }

    func testMonthlySalaryPayRuleUsesStandardFullTimeMonthlyPaidHours() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 13, calendar: calendar)
        let assumptions = SalaryAssumptions.standardFullTime
        let payRule = PayRule.monthlySalary(8_000)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(payRule: payRule, workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(assumptions.monthlyPaidHours, (40 * 52) / 12)
        assertDecimal(snapshot.derivedHourlyRate, equals: 8_000 / assumptions.monthlyPaidHours)
        assertDecimal(snapshot.accruedAmount, equals: (8_000 / assumptions.monthlyPaidHours) * 4)
    }

    func testAnnualSalaryPayRuleUsesStandardFullTimeAnnualPaidHours() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 13, calendar: calendar)
        let assumptions = SalaryAssumptions.standardFullTime
        let payRule = PayRule.annualSalary(120_000)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(payRule: payRule, workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(assumptions.annualPaidHours, 40 * 52)
        assertDecimal(snapshot.derivedHourlyRate, equals: 120_000 / assumptions.annualPaidHours)
        assertDecimal(snapshot.accruedAmount, equals: (120_000 / assumptions.annualPaidHours) * 4)
    }

    func testCurrencyFormatsSelectedCurrencyWithoutExchangeConversion() throws {
        let calendar = calendar()
        let date = try date(year: 2026, month: 5, day: 19, hour: 13, calendar: calendar)

        let snapshot = AccrueSnapshotCalculator().snapshot(
            for: configuration(currencyCode: "EUR", payRule: .hourlyRate(50), workingWeekdays: [3]),
            at: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(snapshot.currencyCode, "EUR")
        XCTAssertEqual(snapshot.accruedAmount, 200)
        XCTAssertEqual(snapshot.formattedAccruedAmount, "€200.00")
    }

    private func configuration(workingWeekdays: Set<Int>) -> AccrueConfiguration {
        configuration(payRule: .hourlyRate(50), workingWeekdays: workingWeekdays)
    }

    private func configuration(
        currencyCode: String = "USD",
        payRule: PayRule,
        workingWeekdays: Set<Int>
    ) -> AccrueConfiguration {
        AccrueConfiguration(
            currencyCode: currencyCode,
            payRule: payRule,
            workStartHour: 9,
            workEndHour: 17,
            workingWeekdays: workingWeekdays
        )
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date)
    }

    private func assertDecimal(
        _ actual: Decimal?,
        equals expected: Decimal,
        accuracy: Double = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualValue = NSDecimalNumber(decimal: actual ?? 0).doubleValue
        let expectedValue = NSDecimalNumber(decimal: expected).doubleValue
        XCTAssertEqual(actualValue, expectedValue, accuracy: accuracy, file: file, line: line)
    }

    private func assertDecimal(
        _ actual: Decimal,
        equals expected: Decimal,
        accuracy: Double = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertDecimal(Optional(actual), equals: expected, accuracy: accuracy, file: file, line: line)
    }
}
