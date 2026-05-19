import AccrueCore
import AccrueAppSupport
import AppKit
import SwiftData
import SwiftUI

@main
struct AccrueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AccrueAppModel.shared
    @AppStorage("showMenuBarPresence") private var showMenuBarPresence = true

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarPresence) {
            AccrueMenuContent()
                .environmentObject(appModel)
        } label: {
            AccrueMenuBarLabel()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AccrueAppModel.shared.openActivationSetupIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AccrueAppModel.shared.openActivationSetup()
        return true
    }
}

@MainActor
final class AccrueAppModel: ObservableObject {
    static let shared = AccrueAppModel()

    @Published private(set) var setupError: String?

    let configurationStore: AccrueConfigurationStore
    let launchAtLoginController = LaunchAtLoginController()

    private var setupWindow: NSWindow?

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

    func openActivationSetupIfNeeded() {
        guard configurationStore.configuration == nil else {
            NSApplication.shared.setActivationPolicy(.accessory)
            return
        }

        openActivationSetup()
    }

    func openActivationSetup() {
        NSApplication.shared.setActivationPolicy(.regular)

        if let setupWindow {
            setupWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = ActivationSetupView()
            .environmentObject(self)
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 460, height: 520)
        let screen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1800, height: 1130)
        let windowFrame = NSRect(
            x: screenFrame.midX - 230,
            y: screenFrame.midY - 260,
            width: 460,
            height: 520
        )
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Activation Setup"
        window.contentView = hostingController.view
        window.collectionBehavior = [.moveToActiveSpace]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.setFrame(windowFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        setupWindow = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func saveSetup(_ draft: AccrueSetupDraft) {
        do {
            try configurationStore.save(draft)
            setupError = nil
            setupWindow?.close()
            setupWindow = nil
            NSApplication.shared.setActivationPolicy(.accessory)
        } catch {
            setupError = error.localizedDescription
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginController.setEnabled(enabled)
    }
}

private struct AccrueMenuBarLabel: View {
    @EnvironmentObject private var appModel: AccrueAppModel
    @AppStorage("accrueDisplayMode") private var displayModeRawValue = AccrueDisplayMode.calm.rawValue
    @AppStorage("stealthModeEnabled") private var stealthModeEnabled = false

    private let calculator = AccrueSnapshotCalculator()
    private let renderer = MenuBarPresenceRenderer()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = calculator.snapshot(for: appModel.configuration, at: timeline.date)
            let display = renderer.display(
                for: snapshot,
                preferences: MenuBarDisplayPreferences(
                    displayMode: AccrueDisplayMode(rawValue: displayModeRawValue) ?? .calm,
                    stealthModeEnabled: stealthModeEnabled
                )
            )

            switch display {
            case .amount(let amount):
                Text(amount)
                    .monospacedDigit()
            case .amountWithRate(let amount, let hourlyRate):
                Text("\(amount) \(hourlyRate)")
                    .monospacedDigit()
            case .symbol(let systemName):
                Image(systemName: systemName)
            }
        }
        .onAppear {
            appModel.openActivationSetupIfNeeded()
        }
    }
}

private struct AccrueMenuContent: View {
    @EnvironmentObject private var appModel: AccrueAppModel
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

                Toggle("Stealth Mode", isOn: $stealthModeEnabled)

                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLoginController.isEnabled },
                    set: { enabled in
                        appModel.setLaunchAtLoginEnabled(enabled)
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
