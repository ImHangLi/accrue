# Use pure snapshot calculation

Accrue calculates the current display state with a pure snapshot function that takes configuration, calendar, and current time. SwiftUI views render those snapshots on a timeline instead of relying on a global timer service, keeping accrual logic testable, reusable, and separate from view lifecycle concerns.
