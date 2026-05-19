import Foundation

public enum AccrueAnalyticsEvent: String, CaseIterable, Equatable, Sendable {
    case appOpened = "Accrue.appOpened"
    case setupCompleted = "Accrue.setupCompleted"
    case popoverOpened = "Accrue.popoverOpened"
    case displayModeChanged = "Accrue.displayModeChanged"
    case stealthModeChanged = "Accrue.stealthModeChanged"
    case launchAtLoginChanged = "Accrue.launchAtLoginChanged"
}

public enum AccrueAnalyticsParameter: String, CaseIterable, Equatable, Sendable {
    case displayMode
    case enabled
    case launchAtLoginStatus
    case payRuleKind
}

public struct AccrueAnalyticsSignal: Equatable, Sendable {
    public let name: String
    public let parameters: [String: String]

    public init(name: String, parameters: [String: String]) {
        self.name = name
        self.parameters = parameters
    }
}

public protocol AccrueAnalyticsSink: AnyObject {
    func send(_ signal: AccrueAnalyticsSignal)
}

public final class AccrueAnalytics {
    private let isEnabled: () -> Bool
    private let sink: AccrueAnalyticsSink

    public init(isEnabled: @escaping () -> Bool, sink: AccrueAnalyticsSink) {
        self.isEnabled = isEnabled
        self.sink = sink
    }

    public func track(
        _ event: AccrueAnalyticsEvent,
        parameters: [AccrueAnalyticsParameter: String] = [:]
    ) {
        guard isEnabled() else {
            return
        }

        sink.send(AccrueAnalyticsSignal(
            name: event.rawValue,
            parameters: Dictionary(uniqueKeysWithValues: parameters.map { ($0.key.rawValue, $0.value) })
        ))
    }
}
