<p align="center">
  <img src="Assets/AppIcon/iSnapNuke.jpg" width="120" alt="iSnapNuke icon">
</p>

<h1 align="center">iSnapNuke</h1>

<p align="center">A cautious macOS app for inspecting APFS snapshots and deleting only the snapshots that meet conservative safety rules.</p>

<p align="center"><a href="README.zh-TW.md">繁體中文</a></p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-000000?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Platform: macOS 14 or later">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&amp;logo=swift&amp;logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/License-MIT-80C342?style=for-the-badge" alt="License: MIT">
</p>

<p align="center">
  <a href="#features">Features</a> · <a href="#why-i-made-this">Why I Made This</a> · <a href="#screenshots">Screenshots</a> · <a href="#safety-rules">Safety Rules</a> · <a href="#fuck-it-mode">Fuck It Mode</a> · <a href="#how-it-works">How It Works</a> · <a href="#installation">Installation</a> · <a href="#updates">Updates</a> · <a href="#build-from-source">Build from Source</a> · <a href="#release-process">Release Process</a> · <a href="#faq">FAQ</a>
</p>

---

> Deleting an APFS snapshot is irreversible and can remove a system or backup restore point. Read the safety rules before deleting anything.

<a id="about"></a>

## About

iSnapNuke is a local macOS utility for viewing APFS snapshots on the current System and Data volumes. It presents snapshot metadata in a normal macOS window, separates snapshots that meet its conservative deletion rules from protected ones, and requires an explicit confirmation before it runs a deletion command.

The app appears in the Dock, does not install a background service, and does not automatically delete snapshots.

<a id="why-i-made-this"></a>

## Why I Made This

<!-- Write your reason for making iSnapNuke here. -->

<a id="features"></a>

## Features

- Reads APFS snapshots from the current System and Data volumes.
- Shows each snapshot's name, UUID, XID, source inference, APFS metadata, and APFS Private Size when available.
- Infers known snapshot sources from their names, including macOS Update, Time Machine, and Synology Active Backup.
- Separates snapshots into **Eligible for deletion** and **Protected** groups using conservative safety rules.
- Supports multi-selection, an irreversible-action confirmation dialog, a fresh safety scan before every deletion, progress feedback, and a per-item result summary.
- Attempts standard deletion first and offers an administrator-authorized retry when macOS denies that operation for a likely permission reason.
- Includes a session-only **Fuck It Mode** for deliberately attempting protected snapshots with administrator authorization.
- Supports English and Traditional Chinese interfaces.

<a id="screenshots"></a>

## Screenshots

Screenshots are coming soon.

<a id="safety-rules"></a>

## Safety Rules

In normal mode, a snapshot can be selected only when all of the following conditions are true:

1. It is on the Data volume.
2. APFS reports `Purgeable` as `Yes`.
3. It is not a `RevertTo` snapshot.
4. It is not a `RootTo` snapshot.
5. Its name does not start with `com.apple.os.update`.
6. Its name and required APFS metadata are present and valid.
7. Its UUID and volume device identifier match the expected formats.

Anything with missing or unknown metadata is protected. A snapshot that meets these rules is still a restore point: deleting it removes the ability to restore that volume to the corresponding point in time.

Time Machine and third-party backup snapshots are identified for visibility, not automatically preserved by name alone. If one meets the normal eligibility rules, deleting it can remove its local restore point. Review every selected snapshot carefully.

> **Estimated reclaimable space:** iSnapNuke uses APFS Private Size as an estimate of the data referenced only by that snapshot. APFS snapshots can share blocks, so deleting one or more snapshots may free a different amount of disk space. If the value cannot be read, the app shows it as unavailable instead of guessing.

<a id="fuck-it-mode"></a>

## Fuck It Mode

Fuck It Mode is off by default, is acknowledged in its own warning dialog, and lasts only for the current app session. It is never saved.

When enabled, it allows selection of any protected snapshot whose UUID and device identifier pass command-input validation. The app then requests macOS administrator authorization and attempts each selected snapshot individually. This includes macOS update snapshots, System volume snapshots, Time Machine snapshots, third-party backup snapshots, and snapshots from unknown sources.

The mode keeps the pre-delete rescan and input-format checks, but bypasses iSnapNuke's protection classification. Deletion cannot be undone, may remove system or backup restore points, and macOS can still reject individual requests. Unlike a normal batch, a force-deletion batch continues after failures and lists every successful, skipped, and failed item.

<a id="how-it-works"></a>

## How It Works

iSnapNuke reads volume and snapshot information with:

```sh
diskutil info -plist /
diskutil info -plist /System/Volumes/Data
diskutil apfs listSnapshots <device> -plist
```

It evaluates the returned APFS metadata against the safety rules above and reads APFS Private Size when the operating system makes it available.

After you select snapshots and confirm the dialog, iSnapNuke scans again and re-evaluates each selected snapshot immediately before deletion. A normal deletion uses:

```sh
diskutil apfs deleteSnapshot <device> -uuid <uuid> -wait
```

If normal deletion fails because of permissions, the result screen can offer a retry that asks macOS for administrator authorization. Fuck It Mode always uses administrator authorization. Normal batches stop at the first failed or skipped snapshot; force-deletion batches continue item by item.

<a id="installation"></a>

## Installation

### System Requirements

- Apple Silicon Mac
- macOS 14 or later

### Prebuilt Releases

Download the Apple Silicon DMG from the [GitHub Releases page](https://github.com/League2EB/iSnapNuke/releases), open it, and drag `iSnapNuke.app` to the Applications shortcut.

Public builds are signed with a Developer ID certificate and notarized by Apple.

<a id="updates"></a>

## Updates

iSnapNuke's direct-download build has no application backend. It reads a small, signed update policy from this repository and uses signed Sparkle disk images for installation.

- If the installed build is behind the latest build but still supported, the app shows a dismissible **Update Available** sheet.
- If the installed build is below `minimumSupportedBuild`, the app replaces its main UI with **Update Required**. The only actions are update, retry the policy check, or quit.
- The last valid policy is cached locally. If GitHub cannot be reached, a cached required-update policy remains enforced. A first launch with no policy cache fails open, so offline users are not locked out merely because the policy could not be retrieved.
- Policy requests use HTTPS and ETag validation. The request does not include APFS metadata, account information, or telemetry.

The policy and Sparkle appcast are published at fixed repository paths:

- `https://raw.githubusercontent.com/League2EB/iSnapNuke/main/update-policy.json`
- `https://raw.githubusercontent.com/League2EB/iSnapNuke/main/appcast.xml`

### Local update-flow demo

The demo never downloads an archive, writes an update-policy cache, or runs `diskutil`. It uses the app's existing safe snapshot demo mode as well.

```sh
./scripts/demo-update.sh optional  # Update Available sheet
./scripts/demo-update.sh required  # Update Required blocker
./scripts/demo-update.sh upToDate  # normal demo app
./scripts/demo-update.sh offline   # first-launch offline fallback
```

For the first two cases, choose **Update Now** to verify the installation handoff. The app shows a confirmation that the operation is a local demo and does not install anything.

<a id="build-from-source"></a>

## Build from Source

Run these commands from a local checkout of the project:

```sh
swift test
./scripts/build-app.sh
open dist/iSnapNuke.app
```

`build-app.sh` builds a Release app bundle at `dist/iSnapNuke.app`, generates the `.icns` app icon from `Assets/AppIcon/iSnapNuke.jpg`, and ad-hoc signs the bundle for local use.

Building from source requires the Xcode Command Line Tools.

If Gatekeeper blocks the first launch, Control-click the app in Finder and choose **Open**. Closing the main window quits the app.

<a id="release-process"></a>

## Release Process

Do not publish a bare tag as an app release. Every public version needs a GitHub Release asset, a signed Sparkle appcast entry, and a signed update policy.

### One-time key setup

1. Generate the policy-signing key outside this repository:

   ```sh
   swift run iSnapNukeReleaseTool generate-policy-key \
     --private-key "$HOME/.config/iSnapNuke/update-policy.key"
   ```

   Save the printed public key. Keep that private-key file private; do not commit it.

2. Use Sparkle's official [`generate_keys`](https://sparkle-project.org/documentation/publishing/) utility to create the Sparkle EdDSA key pair in Keychain. This project uses the account `com.xuanci.isnapnuke`. Retain the printed public key.

3. Install a Developer ID Application certificate and store App Store Connect notarization credentials in a `notarytool` Keychain profile. The local profile used by the commands below is `iSnapNuke-notary`.

4. Create a fine-grained GitHub PAT limited to `League2EB/iSnapNuke` with `Contents: Read and write`, then store it in Keychain under service `iSnapNuke-gh-pat` and account `League2EB`. Enter it without placing it in shell history:

   ```zsh
   read -s "TOKEN?GitHub PAT: "; print
   security add-generic-password -U \
     -a League2EB \
     -s iSnapNuke-gh-pat \
     -w "$TOKEN"
   unset TOKEN
   ```

   Git pushes continue to use SSH; the PAT is only used by `gh` for release API calls.

5. Export the public keys and signing identity in a secure release shell or CI secret store:

   ```sh
   export UPDATE_POLICY_PUBLIC_KEY="<policy public key>"
   export SPARKLE_PUBLIC_KEY="<Sparkle public key>"
   export SIGNING_IDENTITY="Developer ID Application: XuanCi Tech. Co., Ltd. (T46J69KN43)"
   export NOTARY_PROFILE="iSnapNuke-notary"
   ```

   The project intentionally does not store certificates, private keys, tokens, or notarization credentials.

### Per-release checklist

1. Bump both version fields with an increasing build number:

   ```sh
   ./scripts/set-version.sh 1.1.0 2
   ```

2. With the same secure release environment variables set, build and verify the Developer ID app, then create, sign, notarize, staple, and verify the Apple Silicon DMG:

   ```sh
   REQUIRE_UPDATE_KEYS=1 ./scripts/build-app.sh
   ./scripts/verify-app-bundle.sh
   NOTARIZE=1 ./scripts/package-update.sh
   ```

   The resulting asset is `dist/release/iSnapNuke-1.1.0-2-arm64.dmg` and contains `iSnapNuke.app` plus an `/Applications` shortcut.

3. Generate the EdDSA-signed Sparkle appcast entry from the final notarized DMG:

   ```sh
   VERSION=1.1.0
   BUILD=2
   TAG="v$VERSION"
   DMG="dist/release/iSnapNuke-$VERSION-$BUILD-arm64.dmg"
   FEED_DIR=".build/release-feed/$TAG"
   mkdir -p "$FEED_DIR"
   cp "$DMG" "$FEED_DIR/"
   .build/artifacts/sparkle/Sparkle/bin/generate_appcast \
     --account com.xuanci.isnapnuke \
     --download-url-prefix "https://github.com/League2EB/iSnapNuke/releases/download/$TAG/" \
     -o appcast.xml \
     "$FEED_DIR"
   ```

4. Copy `Packaging/update-policy.template.json`, set the new versions, build numbers, release notes, and ISO-8601 publication date. Sign it:

   ```sh
   swift run iSnapNukeReleaseTool sign-policy \
     --policy /path/to/policy-input.json \
     --private-key "$HOME/.config/iSnapNuke/update-policy.key" \
     --output update-policy.json
   swift run iSnapNukeReleaseTool verify-policy \
     --policy update-policy.json \
     --public-key "<policy public key>"
   ```

5. Commit all release changes, create the matching tag at that commit, validate it, then push the branch and tag over SSH:

   ```sh
   git tag -a "$TAG" -m "iSnapNuke $VERSION"
   ./scripts/validate-release.sh "$TAG"
   git push origin main "$TAG"
   ```

6. Create the public GitHub Release with the Keychain-backed PAT and upload the DMG:

   ```sh
   TOKEN="$(security find-generic-password \
     -a League2EB -s iSnapNuke-gh-pat -w)"
   GH_TOKEN="$TOKEN" /opt/homebrew/bin/gh release create "$TAG" "$DMG" \
     --repo League2EB/iSnapNuke \
     --title "iSnapNuke $VERSION" \
     --notes-file /path/to/release-notes.md
   unset TOKEN
   ```

7. Download the public release asset again, compare its SHA-256 checksum with the local DMG, and repeat the DMG, stapler, code-signing, and Gatekeeper checks before announcing the release.

To publish a non-mandatory update, keep `minimumSupportedBuild` at the previous supported build. Only raise it after the newer GitHub Release asset is publicly downloadable and installs correctly. Never lower an existing minimum build: clients reject a policy rollback.

<a id="language-support"></a>

## Language Support

- Traditional Chinese is used when the preferred system language is `zh-Hant`, `zh-TW`, `zh-HK`, or `zh-MO`.
- English is the default and fallback for every other system language, including Simplified Chinese and Japanese.

<a id="faq"></a>

## FAQ

### Does iSnapNuke modify macOS or delete snapshots automatically?

No. It reads APFS metadata locally and runs a deletion command only after you explicitly select snapshots and confirm the irreversible-action dialog. It does not modify macOS system files or snapshot contents.

### Why is a snapshot protected?

It may be on the System volume, not marked purgeable, a current revert or root snapshot, a macOS update snapshot, or have incomplete or invalid metadata. Missing information is treated as unsafe.

### What happens if macOS denies deletion?

The normal result screen identifies the failure. For likely permission failures, it can offer a retry that asks macOS for administrator authorization. A failed normal batch stops at that item so you can review the result.

### Can I delete Time Machine or Synology Active Backup snapshots?

Their names are shown as source inferences, but normal eligibility is based on APFS metadata and the safety rules. Deleting an eligible backup snapshot can still remove a local restore point. Fuck It Mode can attempt protected backup snapshots as well, at considerably greater risk.

### Does APFS Private Size equal the space I will recover?

Not exactly. It measures data referenced only by a snapshot and is a useful estimate, but snapshots can share APFS blocks. The final amount of freed disk space can be higher or lower.

<a id="privacy"></a>

## Privacy

iSnapNuke operates locally. It does not install a background service, collect telemetry, or upload snapshot data. Snapshot operations have no network communication. Direct-download builds make HTTPS requests to GitHub only to retrieve the signed update policy and, after you choose **Update Now**, the signed release disk image.

<a id="license"></a>

## License

This project is licensed under the [MIT License](LICENSE).
