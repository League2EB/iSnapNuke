import SwiftUI
import iSnapNukeCore
import iSnapNukeLocalization

struct DeleteConfirmationSheet: View {
    let snapshots: [AssessedSnapshot]
    let isDeleting: Bool
    let isForceDeletion: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var totalPrivateSizeBytes: Int64? {
        let sizes = snapshots.compactMap(\.snapshot.privateSizeBytes)
        guard sizes.count == snapshots.count else {
            return nil
        }
        return sizes.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(iSnapNukeTheme.destructive)

                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        L10n.format(
                            isForceDeletion
                                ? (snapshots.count == 1
                                    ? "confirm.force_title"
                                    : "confirm.force_title_plural")
                                : (snapshots.count == 1
                                    ? "confirm.title"
                                    : "confirm.title_plural"),
                            snapshots.count
                        )
                    )
                        .font(.title3.weight(.bold))
                        .foregroundStyle(iSnapNukeTheme.foreground)
                    Text(L10n.text("confirm.body"))
                        .font(.subheadline)
                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(snapshots) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.snapshot.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(iSnapNukeTheme.foreground)
                            Text(item.snapshot.rawUUID)
                                .font(.caption.monospaced())
                                .foregroundStyle(iSnapNukeTheme.mutedForeground)
                            Text(
                                L10n.format(
                                    "size.estimated_reclaimable",
                                    L10n.byteCount(item.snapshot.privateSizeBytes)
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(iSnapNukeTheme.accent)
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(iSnapNukeTheme.muted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
                .frame(maxHeight: 190)

            VStack(alignment: .leading, spacing: 5) {
                Text(
                    L10n.format(
                        "confirm.total_reclaimable",
                        L10n.byteCount(totalPrivateSizeBytes)
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(iSnapNukeTheme.accent)
                Text(L10n.text("confirm.total_note"))
                    .font(.caption)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
            }

            Text(
                L10n.text(
                    isForceDeletion
                        ? "confirm.force_warning"
                        : "confirm.backup_warning"
                )
            )
                .font(.caption)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)

            HStack {
                Button(L10n.text("action.cancel"), role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(role: .destructive, action: onConfirm) {
                    Label(
                        L10n.text(
                            isForceDeletion
                                ? "action.force_delete_permanently"
                                : "action.delete_permanently"
                        ),
                        systemImage: "trash"
                    )
                }
                    .buttonStyle(.borderedProminent)
                    .tint(iSnapNukeTheme.destructive)
                    .disabled(isDeleting || snapshots.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
            .padding(22)
            .frame(width: 460)
            .background(iSnapNukeTheme.background)
    }
}
