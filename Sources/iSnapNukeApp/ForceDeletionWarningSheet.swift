import SwiftUI
import iSnapNukeLocalization

struct ForceDeletionWarningSheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(iSnapNukeTheme.destructive)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("force.mode.warning_title"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(iSnapNukeTheme.foreground)
                    Text(L10n.text("force.mode.warning_body"))
                        .font(.subheadline)
                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                }
            }

            Text(L10n.text("force.mode.warning_note"))
                .font(.caption)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)

            HStack {
                Button(L10n.text("action.cancel"), role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(role: .destructive, action: onConfirm) {
                    Label(
                        L10n.text("force.mode.acknowledge"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
                    .buttonStyle(.borderedProminent)
                    .tint(iSnapNukeTheme.destructive)
                    .keyboardShortcut(.defaultAction)
            }
        }
            .padding(22)
            .frame(width: 480)
            .background(iSnapNukeTheme.background)
    }
}
