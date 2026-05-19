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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appModel = AccrueAppModel.shared
    private let telemetryController = AccrueTelemetryController.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
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
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 438, height: 648)
        popover.contentViewController = NSHostingController(
            rootView: AccrueMenuContent()
                .environmentObject(appModel)
                .environmentObject(telemetryController)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    private func updateStatusItem() {
        let snapshot = AccrueSnapshotCalculator().snapshot(for: appModel.configuration, at: Date())
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

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            appModel.launchAtLoginController.refresh()
            telemetryController.track(.popoverOpened)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
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

private struct AccrueMenuContent: View {
    @EnvironmentObject private var appModel: AccrueAppModel
    @EnvironmentObject private var telemetryController: AccrueTelemetryController
    @ObservedObject private var launchAtLoginController = AccrueAppModel.shared.launchAtLoginController
    @AppStorage("accrueDisplayMode") private var displayModeRawValue = AccrueDisplayMode.calm.rawValue
    @AppStorage("stealthModeEnabled") private var stealthModeEnabled = false
    @State private var isMoreSettingsExpanded = false

    private let calculator = AccrueSnapshotCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = calculator.snapshot(for: appModel.configuration, at: timeline.date)
            let model = AccruePopoverSnapshotViewModel(
                snapshot: snapshot,
                configuration: appModel.configuration
            )

            VStack(alignment: .leading, spacing: 22) {
                popoverHeader(for: model)
                amountPanel(for: model)
                progressPanel(for: model)
                metricsPanel(for: model, snapshot: snapshot)
                presenceControls()
                settingsDisclosure(for: model)
            }
            .padding(28)
            .frame(width: 438, alignment: .leading)
            .onAppear {
                appModel.launchAtLoginController.refresh()
                telemetryController.track(.popoverOpened)
            }
        }
    }

    private func popoverHeader(for model: AccruePopoverSnapshotViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Day Accrual")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Today")
                    .font(.system(size: 32, weight: .bold, design: .default))
            }

            Spacer()

            Text(model.stateLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.stateTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(model.stateTint.opacity(0.14), in: Capsule())
        }
    }

    private func amountPanel(for model: AccruePopoverSnapshotViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.amountText)
                .font(.system(size: 72, weight: .bold, design: .default).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            HStack {
                Text("Projected final")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.projectedFinalText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.quaternary)
        }
    }

    private func progressPanel(for model: AccruePopoverSnapshotViewModel) -> some View {
        HStack(spacing: 18) {
            Gauge(value: model.progress) {
                Text("Progress")
            } currentValueLabel: {
                Text(model.progressPercentText)
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.yellow)
            .frame(width: 82)

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: model.progress)
                    .tint(.yellow)

                Text(model.progressDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metricsPanel(
        for model: AccruePopoverSnapshotViewModel,
        snapshot: AccrueSnapshot
    ) -> some View {
        HStack(spacing: 0) {
            MetricCell(label: "Rate", value: formatHourlyRate(snapshot))
            Divider()
            MetricCell(label: "Pay Rule", value: model.payRuleText)
            Divider()
            MetricCell(label: "Reset", value: model.resetText)
        }
        .frame(height: 68)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func presenceControls() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Presence")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Menu Bar Presence", selection: presenceModeBinding) {
                Text("Calm").tag(AccruePresenceMode.calm)
                Text("Rate").tag(AccruePresenceMode.rate)
                Text("Stealth").tag(AccruePresenceMode.stealth)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
        .padding(.top, 2)
    }

    private func settingsDisclosure(for model: AccruePopoverSnapshotViewModel) -> some View {
        DisclosureGroup(isExpanded: $isMoreSettingsExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                AccrueSettingsRow(label: "Working Hours", value: model.workingHoursText)
                AccrueSettingsToggleRow(
                    label: "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { enabled in
                            appModel.setLaunchAtLoginEnabled(enabled)
                            telemetryController.track(
                                .launchAtLoginChanged,
                                parameters: [
                                    .enabled: String(enabled),
                                    .launchAtLoginStatus: launchAtLoginController.statusLabel,
                                ]
                            )
                        }
                    )
                )
                if let errorMessage = launchAtLoginController.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.vertical, 6)
                }
                AccrueSettingsToggleRow(
                    label: "Product Analytics",
                    isOn: Binding(
                        get: { telemetryController.isAvailable && !telemetryController.isOptedOut },
                        set: { enabled in
                            if telemetryController.isAvailable {
                                telemetryController.isOptedOut = !enabled
                            }
                        }
                    )
                )
                .disabled(!telemetryController.isAvailable)
                if !telemetryController.isAvailable {
                    Text("Analytics off for this source build")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
                AccrueSettingsActionRow(label: "Activation Setup") {
                    appModel.openActivationSetup()
                }
                AccrueSettingsActionRow(label: "Quit Accrue") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.top, 8)
        } label: {
            Text("More settings")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var presenceModeBinding: Binding<AccruePresenceMode> {
        Binding(
            get: {
                if stealthModeEnabled {
                    return .stealth
                }
                return AccrueDisplayMode(rawValue: displayModeRawValue) == .rate ? .rate : .calm
            },
            set: { mode in
                switch mode {
                case .calm:
                    stealthModeEnabled = false
                    displayModeRawValue = AccrueDisplayMode.calm.rawValue
                    telemetryController.track(.displayModeChanged, parameters: [.displayMode: displayModeRawValue])
                    telemetryController.track(.stealthModeChanged, parameters: [.enabled: "false"])
                case .rate:
                    stealthModeEnabled = false
                    displayModeRawValue = AccrueDisplayMode.rate.rawValue
                    telemetryController.track(.displayModeChanged, parameters: [.displayMode: displayModeRawValue])
                    telemetryController.track(.stealthModeChanged, parameters: [.enabled: "false"])
                case .stealth:
                    stealthModeEnabled = true
                    telemetryController.track(.stealthModeChanged, parameters: [.enabled: "true"])
                }
            }
        )
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

private enum AccruePresenceMode: Hashable {
    case calm
    case rate
    case stealth
}

private struct AccruePopoverSnapshotViewModel {
    let snapshot: AccrueSnapshot
    let configuration: AccrueConfiguration

    var amountText: String {
        snapshot.formattedAccruedAmount ?? "Not accruing"
    }

    var projectedFinalText: String {
        formatCurrency(dailyFinalAmount)
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

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = snapshot.currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(snapshot.currencyCode) \(amount)"
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

private struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

private struct AccrueSettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent {
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 8)
    }
}

private struct AccrueSettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 8)
    }
}

private struct AccrueSettingsActionRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .font(.subheadline.weight(.medium))
        .padding(.vertical, 8)
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
