import AccrueCore
import Foundation

public enum AccrueDisplayMode: String, CaseIterable, Equatable, Sendable {
    case calm
    case rate
}

public struct MenuBarDisplayPreferences: Equatable, Sendable {
    public var displayMode: AccrueDisplayMode
    public var stealthModeEnabled: Bool

    public init(displayMode: AccrueDisplayMode = .calm, stealthModeEnabled: Bool = false) {
        self.displayMode = displayMode
        self.stealthModeEnabled = stealthModeEnabled
    }
}

public enum MenuBarPresenceDisplay: Equatable, Sendable {
    case amount(String)
    case amountWithRate(amount: String, hourlyRate: String)
    case symbol(String)
}

public struct MenuBarPresenceRenderer: Sendable {
    public init() {}

    public func display(
        for snapshot: AccrueSnapshot,
        preferences: MenuBarDisplayPreferences,
        locale: Locale = .current
    ) -> MenuBarPresenceDisplay {
        if preferences.stealthModeEnabled {
            return .symbol("banknote")
        }

        switch snapshot.state {
        case .waiting:
            return .symbol("clock")
        case .rest:
            return .symbol("moon")
        case .accruing, .done:
            let amount = snapshot.formattedAccruedAmount ?? ""

            switch preferences.displayMode {
            case .calm:
                return .amount(amount)
            case .rate:
                return .amountWithRate(
                    amount: amount,
                    hourlyRate: formatHourlyRate(snapshot.derivedHourlyRate, currencyCode: snapshot.currencyCode, locale: locale)
                )
            }
        }
    }

    private func formatHourlyRate(_ amount: Decimal, currencyCode: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return "\(formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode) \(amount)")/h"
    }
}
