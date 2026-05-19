import AccrueCore
import Foundation
import SwiftData

public struct AccrueSetupDraft: Equatable, Sendable {
    public var currencyCode: String
    public var payRuleKind: StoredPayRuleKind
    public var payAmount: Decimal

    public init(
        currencyCode: String,
        payRuleKind: StoredPayRuleKind,
        payAmount: Decimal
    ) {
        self.currencyCode = currencyCode
        self.payRuleKind = payRuleKind
        self.payAmount = payAmount
    }
}

public enum StoredPayRuleKind: String, CaseIterable, Equatable, Sendable {
    case hourlyRate
    case monthlySalary
    case annualSalary

    public var title: String {
        switch self {
        case .hourlyRate:
            "Hourly Rate"
        case .monthlySalary:
            "Monthly Salary"
        case .annualSalary:
            "Annual Salary"
        }
    }

    public func makePayRule(amount: Decimal) -> PayRule {
        switch self {
        case .hourlyRate:
            .hourlyRate(amount)
        case .monthlySalary:
            .monthlySalary(amount)
        case .annualSalary:
            .annualSalary(amount)
        }
    }
}

@Model
public final class StoredAccrueConfiguration {
    public var currencyCode: String
    public var payRuleKindRawValue: String
    public var payAmount: Decimal
    public var workStartHour: Int
    public var workEndHour: Int
    public var workingWeekdays: [Int]

    public init(
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        payRuleKind: StoredPayRuleKind = .hourlyRate,
        payAmount: Decimal = 50,
        workStartHour: Int = 9,
        workEndHour: Int = 17,
        workingWeekdays: [Int] = [2, 3, 4, 5, 6]
    ) {
        self.currencyCode = currencyCode
        self.payRuleKindRawValue = payRuleKind.rawValue
        self.payAmount = payAmount
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.workingWeekdays = workingWeekdays
    }

    public var payRuleKind: StoredPayRuleKind {
        StoredPayRuleKind(rawValue: payRuleKindRawValue) ?? .hourlyRate
    }

    public func apply(_ draft: AccrueSetupDraft) {
        currencyCode = draft.currencyCode
        payRuleKindRawValue = draft.payRuleKind.rawValue
        payAmount = draft.payAmount
    }

    public func toCoreConfiguration() -> AccrueConfiguration {
        AccrueConfiguration(
            currencyCode: currencyCode,
            payRule: payRuleKind.makePayRule(amount: payAmount),
            workStartHour: workStartHour,
            workEndHour: workEndHour,
            workingWeekdays: Set(workingWeekdays)
        )
    }
}
