import AppKit
import SwiftUI
import iSnapNukeCore
import iSnapNukeLocalization

struct UpdateCheckPanel: View {
    var body: some View {
        ZStack {
            iSnapNukeTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(iSnapNukeTheme.primary)

                Text(L10n.text("update.checking_title"))
                    .font(.headline)
                    .foregroundStyle(iSnapNukeTheme.foreground)

                Text(L10n.text("update.checking_body"))
                    .font(.callout)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(32)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RequiredUpdatePanel: View {
    let policy: UpdatePolicy
    let isChecking: Bool
    let onInstall: () -> Void
    let onRetry: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            iSnapNukeTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(iSnapNukeTheme.primary)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(L10n.text("update.required_title"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(iSnapNukeTheme.foreground)

                    Text(
                        L10n.format(
                            "update.required_body",
                            policy.minimumSupportedVersion.description
                        )
                    )
                    .font(.body)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 390)
                }

                UpdateReleaseNotes(policy: policy)

                VStack(spacing: 10) {
                    Button(action: onInstall) {
                        Label(
                            L10n.text("update.install_now"),
                            systemImage: "arrow.down.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(iSnapNukeTheme.primary)

                    Button(action: onRetry) {
                        if isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(L10n.text("update.retry"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isChecking)

                    Button(L10n.text("update.quit"), role: .cancel, action: onQuit)
                        .buttonStyle(.plain)
                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                }
                .frame(width: 260)
            }
            .padding(36)
        }
        .accessibilityElement(children: .contain)
    }
}

struct OptionalUpdateSheet: View {
    let policy: UpdatePolicy
    let onInstall: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.title2)
                    .foregroundStyle(iSnapNukeTheme.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("update.optional_title"))
                        .font(.headline)

                    Text(
                        L10n.format(
                            "update.version_available",
                            policy.latestVersion.description
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
                }
            }

            UpdateReleaseNotes(policy: policy)

            HStack {
                Spacer()

                Button(L10n.text("update.later"), action: onLater)
                    .keyboardShortcut(.cancelAction)

                Button(action: onInstall) {
                    Label(
                        L10n.text("update.install_now"),
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(iSnapNukeTheme.primary)
            }
        }
        .padding(24)
        .frame(width: 420)
        .accessibilityElement(children: .contain)
    }
}

private struct UpdateReleaseNotes: View {
    let policy: UpdatePolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("update.whats_new"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iSnapNukeTheme.foreground)

            Text(
                policy.releaseNote(
                    language: L10n.currentLanguage == .traditionalChinese ? "zh-Hant" : "en"
                ) ?? L10n.text("update.no_release_notes")
            )
            .font(.callout)
            .foregroundStyle(iSnapNukeTheme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(iSnapNukeTheme.muted, in: RoundedRectangle(cornerRadius: 10))
    }
}
