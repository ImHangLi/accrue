# Release Paths

Accrue v1 should stay easy to install while keeping the macOS release checks explicit.

## Mac App Store

The Mac App Store build is the most complete distribution path. Before submission:

- Build with signing and sandboxing enabled.
- Include `PrivacyInfo.xcprivacy`.
- Verify the generated privacy report with TelemetryDeck included.
- Fill the App Store privacy label from the app manifest and analytics docs.
- Confirm Launch at Login works through `SMAppService.mainApp`.

## GitHub Releases

GitHub Releases can host a signed and notarized `.zip` or `.dmg` prerelease for real-user testing before wider distribution.

Direct GitHub downloads do not include v1 auto-update. Users need to download a newer release manually.

## Homebrew Cask

Homebrew Cask can point to a signed and notarized GitHub Release artifact once the release archive and checksum are stable.

## Source Builds

Developers can build from source with Swift Package Manager:

```sh
swift test
swift test --package-path AccrueCore
./script/build_and_run.sh
```

Source builds keep analytics off unless `ACCRUE_TELEMETRYDECK_APP_ID` is provided while building the local app bundle.

## Packaging Checklist

- Run `swift test`.
- Run `swift test --package-path AccrueCore`.
- Run `./script/build_and_run.sh --verify`.
- Run `./script/check_privacy_manifests.sh`.
- Sign the app with the release certificate.
- Enable hardened runtime for notarized direct downloads.
- Enable sandboxing for Mac App Store builds.
- Notarize direct-download artifacts.
- Inspect the app privacy report.
- Confirm no auto-update claim appears for direct GitHub downloads.
