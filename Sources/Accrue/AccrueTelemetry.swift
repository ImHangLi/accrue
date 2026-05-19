import AccrueAppSupport
import Foundation
import TelemetryDeck

@MainActor
final class AccrueTelemetryController: ObservableObject {
    static let shared = AccrueTelemetryController()

    @Published private(set) var isAvailable: Bool
    @Published var isOptedOut: Bool {
        didSet {
            userDefaults.set(isOptedOut, forKey: Self.optOutKey)
            configureSDK()
        }
    }

    private static let optOutKey = "analyticsOptOut"
    private static let appIDInfoKey = "TelemetryDeckAppID"

    private let userDefaults: UserDefaults
    private let appID: String?
    private let analytics: AccrueAnalytics

    private init(userDefaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.userDefaults = userDefaults
        isOptedOut = userDefaults.bool(forKey: Self.optOutKey)
        appID = bundle.object(forInfoDictionaryKey: Self.appIDInfoKey) as? String
        isAvailable = appID?.isEmpty == false

        analytics = AccrueAnalytics(
            isEnabled: {
                guard let appID = bundle.object(forInfoDictionaryKey: Self.appIDInfoKey) as? String else {
                    return false
                }

                return !appID.isEmpty && !userDefaults.bool(forKey: Self.optOutKey)
            },
            sink: TelemetryDeckAnalyticsSink()
        )
    }

    func start() {
        configureSDK()
        track(.appOpened)
    }

    func track(
        _ event: AccrueAnalyticsEvent,
        parameters: [AccrueAnalyticsParameter: String] = [:]
    ) {
        analytics.track(event, parameters: parameters)
    }

    private func configureSDK() {
        guard let appID, !appID.isEmpty, !isOptedOut else {
            TelemetryDeck.terminate()
            isAvailable = appID?.isEmpty == false
            return
        }

        let config = TelemetryDeck.Config(appID: appID)
        config.analyticsDisabled = isOptedOut
        config.sessionStatsEnabled = !isOptedOut
        TelemetryDeck.initialize(config: config)
        isAvailable = true
    }
}

private final class TelemetryDeckAnalyticsSink: AccrueAnalyticsSink {
    func send(_ signal: AccrueAnalyticsSignal) {
        TelemetryDeck.signal(signal.name, parameters: signal.parameters)
    }
}
