import SwiftUI
import iSnapNukeCore
import iSnapNukeLocalization

struct DeletionSummarySheet: View {
    let results: [SnapshotDeletionResult]
    let wasForceDeletion: Bool
    let canRetryWithAdministrator: Bool
    let onDismiss: () -> Void
    let onRetryWithAdministrator: () -> Void

    private var summary: SnapshotDeletionSummary {
        SnapshotDeletionSummary(results: results)
    }

    private var deletedCount: Int {
        summary.deletedCount
    }

    private var issueCount: Int {
        summary.issueCount
    }

    private var isCompleteSuccess: Bool {
        summary.isCompleteSuccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: isCompleteSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(isCompleteSuccess ? iSnapNukeTheme.accent : iSnapNukeTheme.destructive)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isCompleteSuccess ? L10n.text("summary.success_title") : L10n.text("summary.completed_title"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(iSnapNukeTheme.foreground)
                    Text(L10n.format("summary.counts", deletedCount, issueCount))
                        .font(.subheadline)
                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                        ResultRow(result: result, wasForceDeletion: wasForceDeletion)
                    }
                }
            }
            .frame(maxHeight: 190)

            if canRetryWithAdministrator {
                Text(L10n.text("summary.admin_retry"))
                    .font(.caption)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
            }

            if wasForceDeletion {
                Text(L10n.text("summary.force_mode"))
                    .font(.caption)
                    .foregroundStyle(iSnapNukeTheme.destructive)
            }

            HStack {
                Button(L10n.text("action.done"), action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if canRetryWithAdministrator {
                    Button(action: onRetryWithAdministrator) {
                        Label(L10n.text("action.retry_admin"), systemImage: "lock.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(iSnapNukeTheme.destructive)
                }
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(iSnapNukeTheme.background)
        .overlay {
            if isCompleteSuccess {
                DeletionSuccessConfetti()
            }
        }
        .clipped()
    }
}

private struct ResultRow: View {
    let result: SnapshotDeletionResult
    let wasForceDeletion: Bool

    private var isSuccess: Bool {
        if case .deleted = result { return true }
        return false
    }

    private var title: String {
        switch result {
        case .deleted:
            L10n.text("result.deleted")
        case .skipped:
            L10n.text("result.skipped")
        case .failed:
            L10n.text("result.failed")
        }
    }

    private var detail: String? {
        switch result {
        case .deleted:
            nil
        case let .skipped(_, reason):
            reason
        case let .failed(_, message):
            message
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isSuccess ? iSnapNukeTheme.accent : iSnapNukeTheme.destructive)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iSnapNukeTheme.foreground)
                Text(result.uuid.uuidString)
                    .font(.caption.monospaced())
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
                if wasForceDeletion {
                    Text(L10n.text("summary.force_item"))
                        .font(.caption2)
                        .foregroundStyle(iSnapNukeTheme.destructive)
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(iSnapNukeTheme.muted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
