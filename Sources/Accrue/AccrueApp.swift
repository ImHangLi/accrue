import AccrueCore
import AppKit
import SwiftUI

@main
struct AccrueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            AccrueMenuContent()
        } label: {
            AccrueMenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct AccrueMenuBarLabel: View {
    private let calculator = AccrueSnapshotCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = calculator.snapshot(at: timeline.date)

            switch snapshot.state {
            case .waiting:
                Image(systemName: "clock")
            case .accruing, .done:
                Text(snapshot.formattedAccruedAmount ?? "")
                    .monospacedDigit()
            case .rest:
                Image(systemName: "moon")
            }
        }
    }
}

private struct AccrueMenuContent: View {
    private let calculator = AccrueSnapshotCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = calculator.snapshot(at: timeline.date)

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

                Divider()

                Button("Quit Accrue") {
                    NSApp.terminate(nil)
                }
            }
            .padding()
            .frame(width: 240, alignment: .leading)
        }
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
