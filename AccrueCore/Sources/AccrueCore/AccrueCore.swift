import Foundation

public struct AccrueConfiguration: Equatable, Sendable {
    public var currencyCode: String
    public var hourlyRate: Decimal
    public var workStartHour: Int
    public var workEndHour: Int
    public var workingWeekdays: Set<Int>

    public init(
        currencyCode: String,
        hourlyRate: Decimal,
        workStartHour: Int,
        workEndHour: Int,
        workingWeekdays: Set<Int>
    ) {
        self.currencyCode = currencyCode
        self.hourlyRate = hourlyRate
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.workingWeekdays = workingWeekdays
    }

    public static let defaultWorkday = AccrueConfiguration(
        currencyCode: Locale.current.currency?.identifier ?? "USD",
        hourlyRate: 50,
        workStartHour: 9,
        workEndHour: 17,
        workingWeekdays: [2, 3, 4, 5, 6]
    )
}

public enum AccrualState: Equatable, Sendable {
    case waiting
    case accruing
    case done
    case rest
}

public struct AccrueSnapshot: Equatable, Sendable {
    public var state: AccrualState
    public var accruedAmount: Decimal
    public var currencyCode: String
    public var formattedAccruedAmount: String

    public init(
        state: AccrualState,
        accruedAmount: Decimal,
        currencyCode: String,
        formattedAccruedAmount: String
    ) {
        self.state = state
        self.accruedAmount = accruedAmount
        self.currencyCode = currencyCode
        self.formattedAccruedAmount = formattedAccruedAmount
    }
}

public struct AccrueSnapshotCalculator: Sendable {
    public init() {}

    public func snapshot(
        for configuration: AccrueConfiguration = .defaultWorkday,
        at date: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> AccrueSnapshot {
        let weekday = calendar.component(.weekday, from: date)

        guard configuration.workingWeekdays.contains(weekday) else {
            return makeSnapshot(state: .rest, amount: 0, configuration: configuration, locale: locale)
        }

        let start = calendar.date(
            bySettingHour: configuration.workStartHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? date
        let end = calendar.date(
            bySettingHour: configuration.workEndHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? date

        if date < start {
            return makeSnapshot(state: .waiting, amount: 0, configuration: configuration, locale: locale)
        }

        let effectiveEnd = min(date, end)
        let elapsedSeconds = max(0, effectiveEnd.timeIntervalSince(start))
        let elapsedHours = Decimal(elapsedSeconds / 3_600)
        let amount = configuration.hourlyRate * elapsedHours
        let state: AccrualState = date >= end ? .done : .accruing

        return makeSnapshot(state: state, amount: amount, configuration: configuration, locale: locale)
    }

    private func makeSnapshot(
        state: AccrualState,
        amount: Decimal,
        configuration: AccrueConfiguration,
        locale: Locale
    ) -> AccrueSnapshot {
        AccrueSnapshot(
            state: state,
            accruedAmount: amount,
            currencyCode: configuration.currencyCode,
            formattedAccruedAmount: format(amount: amount, currencyCode: configuration.currencyCode, locale: locale)
        )
    }

    private func format(amount: Decimal, currencyCode: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode) \(amount)"
    }
}
