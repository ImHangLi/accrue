import Foundation

public struct AccrueConfiguration: Equatable, Sendable {
    public var currencyCode: String
    public var payRule: PayRule
    public var salaryAssumptions: SalaryAssumptions
    public var workStartHour: Int
    public var workEndHour: Int
    public var workingWeekdays: Set<Int>

    public init(
        currencyCode: String,
        payRule: PayRule,
        salaryAssumptions: SalaryAssumptions = .standardFullTime,
        workStartHour: Int,
        workEndHour: Int,
        workingWeekdays: Set<Int>
    ) {
        self.currencyCode = currencyCode
        self.payRule = payRule
        self.salaryAssumptions = salaryAssumptions
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.workingWeekdays = workingWeekdays
    }

    public static let defaultWorkday = AccrueConfiguration(
        currencyCode: Locale.current.currency?.identifier ?? "USD",
        payRule: .hourlyRate(50),
        workStartHour: 9,
        workEndHour: 17,
        workingWeekdays: [2, 3, 4, 5, 6]
    )
}

public enum PayRule: Equatable, Sendable {
    case hourlyRate(Decimal)
    case monthlySalary(Decimal)
    case annualSalary(Decimal)

    public func derivedHourlyRate(using assumptions: SalaryAssumptions) -> Decimal {
        switch self {
        case .hourlyRate(let amount):
            amount
        case .monthlySalary(let amount):
            amount / assumptions.monthlyPaidHours
        case .annualSalary(let amount):
            amount / assumptions.annualPaidHours
        }
    }
}

public struct SalaryAssumptions: Equatable, Sendable {
    public var hoursPerWeek: Decimal
    public var weeksPerYear: Decimal

    public var annualPaidHours: Decimal {
        hoursPerWeek * weeksPerYear
    }

    public var monthlyPaidHours: Decimal {
        annualPaidHours / 12
    }

    public init(hoursPerWeek: Decimal, weeksPerYear: Decimal) {
        self.hoursPerWeek = hoursPerWeek
        self.weeksPerYear = weeksPerYear
    }

    public static let standardFullTime = SalaryAssumptions(hoursPerWeek: 40, weeksPerYear: 52)
}

public enum AccrualState: Equatable, Sendable {
    case waiting
    case accruing
    case done
    case rest
}

public struct AccrueSnapshot: Equatable, Sendable {
    public var state: AccrualState
    public var accruedAmount: Decimal?
    public var currencyCode: String
    public var formattedAccruedAmount: String?
    public var derivedHourlyRate: Decimal
    public var nextTransition: AccrualTransition?

    public var showsAccruedAmount: Bool {
        accruedAmount != nil
    }

    public init(
        state: AccrualState,
        accruedAmount: Decimal?,
        currencyCode: String,
        formattedAccruedAmount: String?,
        derivedHourlyRate: Decimal,
        nextTransition: AccrualTransition?
    ) {
        self.state = state
        self.accruedAmount = accruedAmount
        self.currencyCode = currencyCode
        self.formattedAccruedAmount = formattedAccruedAmount
        self.derivedHourlyRate = derivedHourlyRate
        self.nextTransition = nextTransition
    }
}

public struct AccrualTransition: Equatable, Sendable {
    public var date: Date
    public var state: AccrualState

    public init(date: Date, state: AccrualState) {
        self.date = date
        self.state = state
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
        let derivedHourlyRate = configuration.payRule.derivedHourlyRate(using: configuration.salaryAssumptions)

        guard configuration.workingWeekdays.contains(weekday) else {
            return makeSnapshot(
                state: .rest,
                amount: nil,
                configuration: configuration,
                derivedHourlyRate: derivedHourlyRate,
                locale: locale,
                nextTransition: nextWorkStart(after: date, configuration: configuration, calendar: calendar)
                    .map { AccrualTransition(date: $0, state: .accruing) }
            )
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
            return makeSnapshot(
                state: .waiting,
                amount: nil,
                configuration: configuration,
                derivedHourlyRate: derivedHourlyRate,
                locale: locale,
                nextTransition: AccrualTransition(date: start, state: .accruing)
            )
        }

        let effectiveEnd = min(date, end)
        let elapsedSeconds = max(0, effectiveEnd.timeIntervalSince(start))
        let elapsedHours = Decimal(elapsedSeconds / 3_600)
        let amount = derivedHourlyRate * elapsedHours
        let state: AccrualState = date >= end ? .done : .accruing
        let nextTransition = nextTransitionAfter(
            date: date,
            workEnd: end,
            state: state,
            configuration: configuration,
            calendar: calendar
        )

        return makeSnapshot(
            state: state,
            amount: amount,
            configuration: configuration,
            derivedHourlyRate: derivedHourlyRate,
            locale: locale,
            nextTransition: nextTransition
        )
    }

    private func makeSnapshot(
        state: AccrualState,
        amount: Decimal?,
        configuration: AccrueConfiguration,
        derivedHourlyRate: Decimal,
        locale: Locale,
        nextTransition: AccrualTransition?
    ) -> AccrueSnapshot {
        AccrueSnapshot(
            state: state,
            accruedAmount: amount,
            currencyCode: configuration.currencyCode,
            formattedAccruedAmount: amount.map {
                format(amount: $0, currencyCode: configuration.currencyCode, locale: locale)
            },
            derivedHourlyRate: derivedHourlyRate,
            nextTransition: nextTransition
        )
    }

    private func nextTransitionAfter(
        date: Date,
        workEnd: Date,
        state: AccrualState,
        configuration: AccrueConfiguration,
        calendar: Calendar
    ) -> AccrualTransition? {
        switch state {
        case .accruing:
            AccrualTransition(date: workEnd, state: .done)
        case .done:
            nextWorkStart(after: date, configuration: configuration, calendar: calendar)
                .map { AccrualTransition(date: $0, state: .accruing) }
        case .waiting, .rest:
            nil
        }
    }

    private func nextWorkStart(
        after date: Date,
        configuration: AccrueConfiguration,
        calendar: Calendar
    ) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)

        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)

            guard configuration.workingWeekdays.contains(weekday),
                  let workStart = calendar.date(
                    bySettingHour: configuration.workStartHour,
                    minute: 0,
                    second: 0,
                    of: day
                  ),
                  workStart > date
            else {
                continue
            }

            return workStart
        }

        return nil
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
