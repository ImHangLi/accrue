import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var status: SMAppService.Status
    @Published public private(set) var errorMessage: String?

    public init() {
        status = SMAppService.mainApp.status
    }

    public var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    public var statusLabel: String {
        switch status {
        case .enabled:
            "Enabled"
        case .requiresApproval:
            "Needs approval in System Settings"
        case .notRegistered:
            "Off"
        case .notFound:
            "Unavailable"
        @unknown default:
            "Unknown"
        }
    }

    public func refresh() {
        status = SMAppService.mainApp.status
    }

    public func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        if enabled {
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "launchAtLoginEnabled")
            } catch {
                errorMessage = error.localizedDescription
            }

            refresh()
            return
        }

        SMAppService.mainApp.unregister { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    UserDefaults.standard.set(false, forKey: "launchAtLoginEnabled")
                }

                self?.refresh()
            }
        }
    }
}
