# Use one local core package

Accrue uses an Xcode app project with one local Swift package, `AccrueCore`, for pure domain logic. The app target owns SwiftUI, SwiftData, analytics, launch-at-login, menu bar integration, and resources, while `AccrueCore` stays free of SwiftUI, SwiftData, AppKit, and platform-specific concerns.
