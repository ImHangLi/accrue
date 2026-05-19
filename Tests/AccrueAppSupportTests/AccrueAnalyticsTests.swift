import AccrueAppSupport
import XCTest

final class AccrueAnalyticsTests: XCTestCase {
    func testTracksOnlyAllowlistedEventsAndParameters() {
        let sink = RecordingAnalyticsSink()
        let analytics = AccrueAnalytics(isEnabled: { true }, sink: sink)

        analytics.track(.displayModeChanged, parameters: [.displayMode: "calm"])

        XCTAssertEqual(sink.signals, [
            AccrueAnalyticsSignal(
                name: AccrueAnalyticsEvent.displayModeChanged.rawValue,
                parameters: [AccrueAnalyticsParameter.displayMode.rawValue: "calm"]
            ),
        ])
        XCTAssertTrue(AccrueAnalyticsEvent.allCases.allSatisfy { $0.rawValue.hasPrefix("Accrue.") })
    }

    func testOptOutPreventsEventEmission() {
        let sink = RecordingAnalyticsSink()
        let analytics = AccrueAnalytics(isEnabled: { false }, sink: sink)

        analytics.track(.popoverOpened)

        XCTAssertTrue(sink.signals.isEmpty)
    }

    func testEventSchemaExcludesCompensationAndExactScheduleFields() {
        let forbiddenNames: Set<String> = [
            "payAmount",
            "payRuleAmount",
            "accruedAmount",
            "formattedAccruedAmount",
            "derivedHourlyRate",
            "workStartHour",
            "workEndHour",
            "workingHours",
            "currencyCode",
        ]

        let eventNames = Set(AccrueAnalyticsEvent.allCases.map(\.rawValue))
        let parameterNames = Set(AccrueAnalyticsParameter.allCases.map(\.rawValue))

        XCTAssertTrue(eventNames.intersection(forbiddenNames).isEmpty)
        XCTAssertTrue(parameterNames.intersection(forbiddenNames).isEmpty)
    }
}

private final class RecordingAnalyticsSink: AccrueAnalyticsSink {
    private(set) var signals: [AccrueAnalyticsSignal] = []

    func send(_ signal: AccrueAnalyticsSignal) {
        signals.append(signal)
    }
}
