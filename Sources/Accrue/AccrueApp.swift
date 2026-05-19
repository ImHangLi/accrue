import AccrueCore
import AccrueAppSupport
import AppKit
import SwiftData
import SwiftUI

@main
enum AccrueMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Accrue menu bar utility")
        AccrueTelemetryController.shared.start()
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let appModel = AccrueAppModel.shared
    private let telemetryController = AccrueTelemetryController.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let calculator = AccrueSnapshotCalculator()
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        updateStatusItem()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }

        appModel.openActivationSetupIfNeeded(
            force: ProcessInfo.processInfo.arguments.contains("--show-setup")
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AccrueAppModel.shared.openActivationSetup()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusMenu.autoenablesItems = false
        statusMenu.delegate = self
        statusItem.menu = statusMenu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildStatusMenu()
        telemetryController.track(.popoverOpened)
    }

    private func updateStatusItem() {
        let snapshot = calculator.snapshot(for: appModel.configuration, at: Date())
        let defaults = UserDefaults.standard
        let displayMode = AccrueDisplayMode(rawValue: defaults.string(forKey: "accrueDisplayMode") ?? AccrueDisplayMode.calm.rawValue) ?? .calm
        let stealthModeEnabled = defaults.bool(forKey: "stealthModeEnabled")
        let display = MenuBarPresenceRenderer().display(
            for: snapshot,
            preferences: MenuBarDisplayPreferences(
                displayMode: displayMode,
                stealthModeEnabled: stealthModeEnabled
            )
        )

        guard let button = statusItem.button else {
            return
        }

        switch display {
        case .amount(let amount):
            button.image = nil
            button.title = amount
        case .amountWithRate(let amount, let hourlyRate):
            button.image = nil
            button.title = "\(amount) \(hourlyRate)"
        case .symbol(let systemName):
            button.title = ""
            button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: "Accrue")
        }
    }

    @objc private func selectCalmPresence() {
        setPresenceMode(.calm)
    }

    @objc private func selectRatePresence() {
        setPresenceMode(.rate)
    }

    @objc private func selectStealthPresence() {
        setPresenceMode(.stealth)
    }

    @objc private func toggleLaunchAtLogin() {
        let enabled = !appModel.launchAtLoginController.isEnabled
        appModel.setLaunchAtLoginEnabled(enabled)
        telemetryController.track(
            .launchAtLoginChanged,
            parameters: [
                .enabled: String(enabled),
                .launchAtLoginStatus: appModel.launchAtLoginController.statusLabel,
            ]
        )
    }

    @objc private func toggleProductAnalytics() {
        guard telemetryController.isAvailable else {
            return
        }

        telemetryController.isOptedOut.toggle()
    }

    @objc private func openActivationSetup() {
        appModel.openActivationSetup()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func rebuildStatusMenu() {
        appModel.launchAtLoginController.refresh()

        let snapshot = calculator.snapshot(for: appModel.configuration, at: Date())
        let model = AccrueStatusMenuModel(snapshot: snapshot, configuration: appModel.configuration)

        statusMenu.removeAllItems()
        statusMenu.addItem(disabledItem("Today"))
        statusMenu.addItem(disabledItem(model.amountText))
        statusMenu.addItem(disabledItem("\(model.stateLabel) - \(model.progressPercentText)"))
        statusMenu.addItem(disabledItem(model.progressDetailText))
        statusMenu.addItem(.separator())
        statusMenu.addItem(disabledItem("Rate: \(formatHourlyRate(snapshot))"))
        statusMenu.addItem(disabledItem("Pay Rule: \(model.payRuleText)"))
        statusMenu.addItem(disabledItem("Working Hours: \(model.workingHoursText)"))
        statusMenu.addItem(.separator())
        statusMenu.addItem(presenceItem("Calm", mode: .calm, action: #selector(selectCalmPresence)))
        statusMenu.addItem(presenceItem("Rate", mode: .rate, action: #selector(selectRatePresence)))
        statusMenu.addItem(presenceItem("Stealth", mode: .stealth, action: #selector(selectStealthPresence)))
        statusMenu.addItem(.separator())
        statusMenu.addItem(toggleItem(
            "Launch at Login",
            isOn: appModel.launchAtLoginController.isEnabled,
            action: #selector(toggleLaunchAtLogin)
        ))
        if let errorMessage = appModel.launchAtLoginController.errorMessage {
            statusMenu.addItem(disabledItem("Launch at Login: \(errorMessage)"))
        }
        statusMenu.addItem(toggleItem(
            "Product Analytics",
            isOn: telemetryController.isAvailable && !telemetryController.isOptedOut,
            action: #selector(toggleProductAnalytics),
            isEnabled: telemetryController.isAvailable
        ))
        if !telemetryController.isAvailable {
            statusMenu.addItem(disabledItem("Analytics off for this build"))
        }
        statusMenu.addItem(.separator())
        statusMenu.addItem(actionItem("Activation Setup...", action: #selector(openActivationSetup)))
        statusMenu.addItem(actionItem("Quit Accrue", action: #selector(quitApp), keyEquivalent: "q"))
    }

    private func setPresenceMode(_ mode: AccruePresenceMode) {
        let defaults = UserDefaults.standard

        switch mode {
        case .calm:
            defaults.set(false, forKey: "stealthModeEnabled")
            defaults.set(AccrueDisplayMode.calm.rawValue, forKey: "accrueDisplayMode")
            telemetryController.track(.displayModeChanged, parameters: [.displayMode: AccrueDisplayMode.calm.rawValue])
            telemetryController.track(.stealthModeChanged, parameters: [.enabled: "false"])
        case .rate:
            defaults.set(false, forKey: "stealthModeEnabled")
            defaults.set(AccrueDisplayMode.rate.rawValue, forKey: "accrueDisplayMode")
            telemetryController.track(.displayModeChanged, parameters: [.displayMode: AccrueDisplayMode.rate.rawValue])
            telemetryController.track(.stealthModeChanged, parameters: [.enabled: "false"])
        case .stealth:
            defaults.set(true, forKey: "stealthModeEnabled")
            telemetryController.track(.stealthModeChanged, parameters: [.enabled: "true"])
        }

        updateStatusItem()
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func presenceItem(_ title: String, mode: AccruePresenceMode, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action: action)
        item.state = currentPresenceMode == mode ? .on : .off
        return item
    }

    private func toggleItem(
        _ title: String,
        isOn: Bool,
        action: Selector,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let item = actionItem(title, action: action)
        item.state = isOn ? .on : .off
        item.isEnabled = isEnabled
        return item
    }

    private func actionItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = true
        return item
    }

    private var currentPresenceMode: AccruePresenceMode {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "stealthModeEnabled") {
            return .stealth
        }
        let rawValue = defaults.string(forKey: "accrueDisplayMode") ?? AccrueDisplayMode.calm.rawValue
        return AccrueDisplayMode(rawValue: rawValue) == .rate ? .rate : .calm
    }

    private func formatHourlyRate(_ snapshot: AccrueSnapshot) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = snapshot.currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return "\(formatter.string(from: snapshot.derivedHourlyRate as NSDecimalNumber) ?? "\(snapshot.currencyCode) \(snapshot.derivedHourlyRate)")/h"
    }
}

@MainActor
final class AccrueAppModel: ObservableObject {
    static let shared = AccrueAppModel()

    @Published private(set) var setupError: String?

    let configurationStore: AccrueConfigurationStore
    let launchAtLoginController = LaunchAtLoginController()
    let telemetryController = AccrueTelemetryController.shared

    private var setupWindowController: NSWindowController?
    var configuration: AccrueConfiguration {
        configurationStore.configuration ?? .defaultWorkday
    }

    private init() {
        do {
            configurationStore = try AccrueConfigurationStore()
        } catch {
            setupError = error.localizedDescription
            configurationStore = try! AccrueConfigurationStore(
                container: .init(for: StoredAccrueConfiguration.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            )
        }
    }

    func openActivationSetupIfNeeded(force: Bool = false) {
        guard force || configurationStore.configuration == nil else {
            NSApplication.shared.setActivationPolicy(.accessory)
            return
        }

        openActivationSetup()
    }

    func openActivationSetup() {
        NSApplication.shared.setActivationPolicy(.regular)

        if let window = setupWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let setupSize = NSSize(width: 460, height: 520)
        let setupView = ActivationSetupView()
            .environmentObject(self)
        let hostingController = NSHostingController(rootView: setupView)
        hostingController.preferredContentSize = setupSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: setupSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Activation Setup"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.setContentSize(setupSize)
        window.minSize = setupSize
        window.center()

        let controller = NSWindowController(window: window)
        setupWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate()
    }

    func saveSetup(_ draft: AccrueSetupDraft) {
        do {
            try configurationStore.save(draft)
            setupError = nil
            setupWindowController?.close()
            setupWindowController = nil
            NSApplication.shared.setActivationPolicy(.accessory)
            telemetryController.track(.setupCompleted, parameters: [.payRuleKind: draft.payRuleKind.rawValue])
        } catch {
            setupError = error.localizedDescription
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginController.setEnabled(enabled)
    }
}

private enum AccruePresenceMode: Hashable {
    case calm
    case rate
    case stealth
}

private struct AccrueStatusMenuModel {
    let snapshot: AccrueSnapshot
    let configuration: AccrueConfiguration

    var amountText: String {
        snapshot.formattedAccruedAmount ?? "Not accruing"
    }

    var progress: Double {
        guard dailyFinalAmount > 0, let accruedAmount = snapshot.accruedAmount else {
            return 0
        }

        let ratio = accruedAmount / dailyFinalAmount
        return min(max((ratio as NSDecimalNumber).doubleValue, 0), 1)
    }

    var progressPercentText: String {
        progress.formatted(.percent.precision(.fractionLength(0)))
    }

    var progressDetailText: String {
        switch snapshot.state {
        case .waiting:
            "Starts at \(hourText(configuration.workStartHour))."
        case .accruing:
            "\(workedTimeText) worked. \(remainingTimeText) remaining."
        case .done:
            "Done for this Day Accrual."
        case .rest:
            "Rest State. Next Working Day starts at \(hourText(configuration.workStartHour))."
        @unknown default:
            "Current Day Accrual status is unknown."
        }
    }

    var stateLabel: String {
        snapshot.state.label
    }

    var stateTint: Color {
        switch snapshot.state {
        case .accruing:
            .green
        case .waiting:
            .blue
        case .done:
            .secondary
        case .rest:
            .secondary
        @unknown default:
            .secondary
        }
    }

    var payRuleText: String {
        switch configuration.payRule {
        case .hourlyRate:
            "Hourly"
        case .monthlySalary:
            "Monthly"
        case .annualSalary:
            "Annual"
        }
    }

    var resetText: String {
        hourText(configuration.workStartHour)
    }

    var workingHoursText: String {
        "\(hourText(configuration.workStartHour))-\(hourText(configuration.workEndHour))"
    }

    private var dailyFinalAmount: Decimal {
        configuration.payRule.derivedHourlyRate(using: configuration.salaryAssumptions) * Decimal(max(configuration.workEndHour - configuration.workStartHour, 0))
    }

    private var workedTimeText: String {
        guard let accruedAmount = snapshot.accruedAmount, snapshot.derivedHourlyRate > 0 else {
            return "0m"
        }

        return formatDuration(hours: accruedAmount / snapshot.derivedHourlyRate)
    }

    private var remainingTimeText: String {
        let totalHours = Decimal(max(configuration.workEndHour - configuration.workStartHour, 0))
        guard let accruedAmount = snapshot.accruedAmount, snapshot.derivedHourlyRate > 0 else {
            return formatDuration(hours: totalHours)
        }

        let workedHours = accruedAmount / snapshot.derivedHourlyRate
        return formatDuration(hours: max(totalHours - workedHours, 0))
    }

    private func hourText(_ hour: Int) -> String {
        "\(hour):00"
    }

    private func formatDuration(hours: Decimal) -> String {
        let minutes = max(0, (hours as NSDecimalNumber).doubleValue * 60)
        let wholeMinutes = Int(minutes.rounded())
        let hourCount = wholeMinutes / 60
        let minuteCount = wholeMinutes % 60

        if hourCount == 0 {
            return "\(minuteCount)m"
        }
        if minuteCount == 0 {
            return "\(hourCount)h"
        }
        return "\(hourCount)h \(minuteCount)m"
    }
}

private extension AccrualState {
    var label: String {
        switch self {
        case .waiting:
            "Waiting State"
        case .accruing:
            "Accruing"
        case .done:
            "Done"
        case .rest:
            "Rest State"
        @unknown default:
            "Unknown"
        }
    }
}
