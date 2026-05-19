# Analytics

Accrue uses TelemetryDeck for privacy-bounded product analytics in official release builds. Source builds default analytics off because the local app bundle has no TelemetryDeck app id unless `ACCRUE_TELEMETRYDECK_APP_ID` is set during `./script/build_and_run.sh`.

## What Is Collected

Accrue only sends allowlisted product interaction events:

- App opened
- Activation setup completed
- Popover opened
- Display mode changed
- Stealth Mode changed
- Launch at Login changed

Allowed event parameters are limited to:

- Display mode
- Boolean enabled state
- Launch at Login status text
- Pay Rule kind

TelemetryDeck generates an anonymous install identity for counting distinct installs. Accrue does not require sign-in for analytics.

## What Is Not Collected

Accrue analytics must not send:

- Pay Rule amount
- Accrued Amount
- Derived hourly rate
- Currency
- Exact Working Hours
- User name, email, or account id

The event schema is typed in code and covered by tests so new analytics fields must be added deliberately.

## Opt Out

Open the menu bar popover and turn off `Product Analytics`. When this is off, Accrue stops initializing TelemetryDeck and prevents event emission through the analytics interface.

Source builds without `ACCRUE_TELEMETRYDECK_APP_ID` show analytics as unavailable and do not send events.

## App Store Privacy

The app includes `PrivacyInfo.xcprivacy` for App Store builds. The manifest declares product interaction analytics, an anonymous device/install identifier used for analytics, no tracking, and UserDefaults required-reason API use.

Before App Store submission, generate and inspect Xcode's privacy report with the TelemetryDeck SDK included in the app build.
