# Accrue

Accrue is a native macOS menu bar app that shows how much of today's workday compensation has accrued. It keeps compensation configuration on device, starts with a short activation setup, and uses a calm menu bar presence for daily use.

## Build from Source

Requirements:

- macOS 14 or newer
- Xcode command line tools

Run tests:

```sh
swift test
swift test --package-path AccrueCore
```

Build and launch the app bundle:

```sh
./script/build_and_run.sh
./script/check_privacy_manifests.sh
```

Source builds do not send product analytics unless `ACCRUE_TELEMETRYDECK_APP_ID` is set while building the local app bundle.

## Docs

- [Analytics](docs/analytics.md)
- [Release paths](docs/release.md)
- [Product context](CONTEXT.md)
