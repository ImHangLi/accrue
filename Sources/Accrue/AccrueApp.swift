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
        popover.contentSize = NSSize(width: 260, height: 440)
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

    private let calculator = AccrueSnapshotCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = calculator.snapshot(for: appModel.configuration, at: timeline.date)

            VStack(alignment: .leading, spacing: 12) {
                Text("Accrue")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Accrued Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.formattedAccruedAmount ?? "Not accruing now")
                        .font(.title2.monospacedDigit())
                }

                Text(snapshot.state.label)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Derived Hourly Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatHourlyRate(snapshot))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Working Hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(appModel.configuration.workStartHour):00-\(appModel.configuration.workEndHour):00")
                }

                Divider()

                Picker("Display", selection: $displayModeRawValue) {
                    Text("Calm").tag(AccrueDisplayMode.calm.rawValue)
                    Text("Rate").tag(AccrueDisplayMode.rate.rawValue)
                }
                .pickerStyle(.segmented)
                .onChange(of: displayModeRawValue) { _, value in
                    telemetryController.track(.displayModeChanged, parameters: [.displayMode: value])
                }

                Toggle("Stealth Mode", isOn: Binding(
                    get: { stealthModeEnabled },
                    set: { enabled in
                        stealthModeEnabled = enabled
                        telemetryController.track(.stealthModeChanged, parameters: [.enabled: String(enabled)])
                    }
                ))

                Toggle("Launch at Login", isOn: Binding(
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
                ))

                Text(launchAtLoginController.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = launchAtLoginController.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Product Analytics", isOn: Binding(
                    get: { telemetryController.isAvailable && !telemetryController.isOptedOut },
                    set: { enabled in
                        if telemetryController.isAvailable {
                            telemetryController.isOptedOut = !enabled
                        }
                    }
                ))
                .disabled(!telemetryController.isAvailable)

                if !telemetryController.isAvailable {
                    Text("Analytics off for this source build")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button("Activation Setup") {
                    appModel.openActivationSetup()
                }

                Button("Quit Accrue") {
                    NSApp.terminate(nil)
                }
            }
            .padding()
            .frame(width: 240, alignment: .leading)
            .onAppear {
                appModel.launchAtLoginController.refresh()
                telemetryController.track(.popoverOpened)
            }
        }
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
