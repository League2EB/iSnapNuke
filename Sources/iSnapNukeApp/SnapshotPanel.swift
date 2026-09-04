import SwiftUI
import iSnapNukeCore
import iSnapNukeLocalization

struct SnapshotPanel: View {
    @ObservedObject var viewModel: SnapshotViewModel

#if DEBUG
    let demoController: DemoModeController?
#endif

    @State private var showsDeleteConfirmation = false
    @State private var showsDeletionSummary = false
    @State private var showsForceDeletionWarning = false
    @State private var hasAcknowledgedForceDeletionWarning = false

    var body: some View {
        ZStack {
            iSnapNukeTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                PanelHeader(
                    deletableCount: viewModel.deletableCount,
                    protectedCount: viewModel.protectedCount,
                    lastScanDate: viewModel.lastScanDate,
                    isRefreshing: viewModel.isLoading || viewModel.isDeleting,
                    isForceDeletionEnabled: viewModel.isForceDeletionEnabled,
                    onRefresh: { Task { await viewModel.refresh() } },
                    onToggleForceDeletion: toggleForceDeletion
                )

#if DEBUG
                if let demoController {
                    DemoControlBar(controller: demoController)
                }
#endif

                if viewModel.isForceDeletionEnabled {
                    ForceDeletionBanner(onDisable: {
                        viewModel.setForceDeletionEnabled(false)
                    })
                }

                Divider()
                    .overlay(iSnapNukeTheme.border)

                panelContent

                Divider()
                    .overlay(iSnapNukeTheme.border)

                PanelFooter(
                    selectionCount: viewModel.selectedSnapshots.count,
                    selectedPrivateSizeBytes: viewModel.selectedPrivateSizeBytes,
                    isDeleting: viewModel.isDeleting,
                    deletionProgress: viewModel.deletionProgress,
                    canDelete: viewModel.canDeleteSelection,
                    isForceDeletionEnabled: viewModel.isForceDeletionEnabled,
                    onDelete: { showsDeleteConfirmation = true }
                )
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .sheet(isPresented: $showsDeleteConfirmation) {
            DeleteConfirmationSheet(
                snapshots: viewModel.selectedSnapshots,
                isDeleting: viewModel.isDeleting,
                isForceDeletion: viewModel.isForceDeletionEnabled,
                onCancel: { showsDeleteConfirmation = false },
                onConfirm: {
                    showsDeleteConfirmation = false
                    Task { await viewModel.deleteSelected() }
                }
            )
        }
        .sheet(isPresented: $showsDeletionSummary) {
            DeletionSummarySheet(
                results: viewModel.deletionResults,
                wasForceDeletion: viewModel.deletionWasForced,
                canRetryWithAdministrator: !viewModel.pendingAdminRetryTargets.isEmpty,
                onDismiss: {
                    showsDeletionSummary = false
                    viewModel.clearDeletionResults()
                },
                onRetryWithAdministrator: {
                    showsDeletionSummary = false
                    viewModel.prepareAdminRetry()
                    Task { await viewModel.retryWithAdministrator() }
                }
            )
        }
        .sheet(isPresented: $showsForceDeletionWarning) {
            ForceDeletionWarningSheet(
                onCancel: { showsForceDeletionWarning = false },
                onConfirm: {
                    hasAcknowledgedForceDeletionWarning = true
                    showsForceDeletionWarning = false
                    viewModel.setForceDeletionEnabled(true)
                }
            )
        }
        .onChange(of: viewModel.deletionResults) { _, results in
            if !results.isEmpty {
                showsDeletionSummary = true
            }
        }
        .alert(
            L10n.text("app.scan_failed_title"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button(L10n.text("action.ok"), role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func toggleForceDeletion() {
        if viewModel.isForceDeletionEnabled {
            viewModel.setForceDeletionEnabled(false)
        } else if hasAcknowledgedForceDeletionWarning {
            viewModel.setForceDeletionEnabled(true)
        } else {
            showsForceDeletionWarning = true
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if viewModel.isLoading && viewModel.snapshots.isEmpty {
            ProgressPanel()
        } else if viewModel.snapshots.isEmpty {
            EmptySnapshotsPanel(onRefresh: { Task { await viewModel.refresh() } })
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(VolumeRole.allCases) { role in
                        let snapshots = viewModel.snapshots.filter { $0.snapshot.volume.role == role }
                        if !snapshots.isEmpty {
                            SnapshotSection(
                                role: role,
                                snapshots: snapshots,
                                selectedIDs: viewModel.selectedIDs,
                                operationStates: viewModel.operationStates,
                                isDeleting: viewModel.isDeleting,
                                isForceDeletionEnabled: viewModel.isForceDeletionEnabled,
                                rowAnimationDuration: viewModel.deletionTiming.rowAnimationDuration,
                                isSelectable: viewModel.isSelectable,
                                canToggleAllEligible: viewModel.canToggleAllEligibleSnapshots,
                                areAllEligibleSelected: viewModel.areAllEligibleSnapshotsSelected,
                                onToggleAllEligible: viewModel.toggleAllEligibleSnapshots,
                                onToggle: viewModel.toggleSelection(for:)
                            )
                        }
                    }
                }
                .padding(16)
            }
            .animation(
                .snappy(duration: viewModel.deletionTiming.rowAnimationDuration),
                value: viewModel.snapshots.map(\.id)
            )
        }
    }
}

private struct PanelHeader: View {
    let deletableCount: Int
    let protectedCount: Int
    let lastScanDate: Date?
    let isRefreshing: Bool
    let isForceDeletionEnabled: Bool
    let onRefresh: () -> Void
    let onToggleForceDeletion: () -> Void
    @State private var refreshRotation = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(iSnapNukeTheme.primary.opacity(0.22))
                        .frame(width: 38, height: 38)
                    Image(systemName: "camera.aperture")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(iSnapNukeTheme.primary)
                        .frame(width: 28, height: 28)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iSnapNuke")
                        .font(.headline)
                        .foregroundStyle(iSnapNukeTheme.foreground)

                    if let lastScanDate {
                        Text(L10n.format("header.last_scanned", L10n.time(lastScanDate)))
                            .font(.caption)
                            .foregroundStyle(iSnapNukeTheme.mutedForeground)
                    } else {
                        Text(L10n.text("header.ready_to_scan"))
                            .font(.caption)
                            .foregroundStyle(iSnapNukeTheme.mutedForeground)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(.linear(duration: 1)) {
                        refreshRotation += 360
                    }
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(refreshRotation))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(iSnapNukeTheme.accent)
                .disabled(isRefreshing)
                .accessibilityLabel(L10n.text("header.refresh_label"))
                .accessibilityHint(L10n.text("header.refresh_hint"))
            }

            Button(action: onToggleForceDeletion) {
                Label(
                    L10n.text(
                        isForceDeletionEnabled
                            ? "force.mode.disable"
                            : "force.mode.enable"
                    ),
                    systemImage: isForceDeletionEnabled
                        ? "exclamationmark.shield.fill"
                        : "exclamationmark.shield"
                )
            }
            .buttonStyle(.bordered)
            .tint(iSnapNukeTheme.destructive)
            .disabled(isRefreshing)
            .accessibilityHint(L10n.text("force.mode.toggle_hint"))

            HStack(spacing: 7) {
                CountBadge(
                    value: deletableCount,
                    title: L10n.text("count.eligible"),
                    foreground: iSnapNukeTheme.accentForeground,
                    background: iSnapNukeTheme.accent
                )
                CountBadge(
                    value: protectedCount,
                    title: L10n.text("count.protected"),
                    foreground: iSnapNukeTheme.foreground,
                    background: iSnapNukeTheme.muted
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct CountBadge: View {
    let value: Int
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text("\(value) \(title)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .accessibilityLabel("\(value) \(title)")
    }
}

private struct SnapshotSection: View {
    let role: VolumeRole
    let snapshots: [AssessedSnapshot]
    let selectedIDs: Set<UUID>
    let operationStates: [UUID: SnapshotOperationState]
    let isDeleting: Bool
    let isForceDeletionEnabled: Bool
    let rowAnimationDuration: TimeInterval
    let isSelectable: (AssessedSnapshot) -> Bool
    let canToggleAllEligible: Bool
    let areAllEligibleSelected: Bool
    let onToggleAllEligible: () -> Void
    let onToggle: (AssessedSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label(role.localizedTitle, systemImage: role == .data ? "internaldrive" : "lock.shield")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iSnapNukeTheme.foreground)

                Text("\(snapshots.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)

                Spacer()

                if role == .data {
                    Button(action: onToggleAllEligible) {
                        Label(
                            L10n.text(
                                areAllEligibleSelected
                                    ? "action.deselect_all"
                                    : "action.select_all_eligible"
                            ),
                            systemImage: areAllEligibleSelected
                                ? "xmark.circle"
                                : "checkmark.circle"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(iSnapNukeTheme.accent)
                    .foregroundStyle(iSnapNukeTheme.accentForeground)
                    .disabled(!canToggleAllEligible)
                    .accessibilityHint(
                        L10n.text(
                            areAllEligibleSelected
                                ? "action.deselect_all_hint"
                                : "action.select_all_eligible_hint"
                        )
                    )
                }
            }

            ForEach(snapshots) { item in
                SnapshotRow(
                    item: item,
                    isSelected: selectedIDs.contains(item.id),
                    operationState: operationStates[item.id],
                    isDeleting: isDeleting,
                    isForceDeletionEnabled: isForceDeletionEnabled,
                    isSelectable: isSelectable(item),
                    rowAnimationDuration: rowAnimationDuration,
                    onToggle: { onToggle(item) }
                )
            }
        }
    }
}

private struct SnapshotRow: View {
    let item: AssessedSnapshot
    let isSelected: Bool
    let operationState: SnapshotOperationState?
    let isDeleting: Bool
    let isForceDeletionEnabled: Bool
    let isSelectable: Bool
    let rowAnimationDuration: TimeInterval
    let onToggle: () -> Void

    @State private var isExpanded = false

    private var snapshot: APFSSnapshot { item.snapshot }

    private var operationDetail: (icon: String, title: String, message: String?, color: Color)? {
        guard let operationState else { return nil }

        switch operationState {
        case let .queued(progress):
            return (
                "clock",
                L10n.format("snapshot.queued", progress.current, progress.total),
                nil,
                iSnapNukeTheme.mutedForeground
            )
        case let .deleting(progress):
            return (
                "progress.indicator",
                L10n.format("snapshot.deleting", progress.current, progress.total),
                nil,
                iSnapNukeTheme.accent
            )
        case .succeeded:
            return (
                "checkmark.circle.fill",
                L10n.text("snapshot.deleted_animating"),
                nil,
                iSnapNukeTheme.accent
            )
        case let .failed(message):
            return (
                "xmark.circle.fill",
                L10n.text("snapshot.delete_failed"),
                message,
                iSnapNukeTheme.destructive
            )
        case let .skipped(reason):
            return (
                "exclamationmark.circle.fill",
                L10n.text("snapshot.delete_skipped"),
                reason,
                iSnapNukeTheme.mutedForeground
            )
        }
    }

    private var isSucceeded: Bool {
        if case .succeeded = operationState {
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if isSelectable {
                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? iSnapNukeTheme.primary : iSnapNukeTheme.mutedForeground)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                    .accessibilityLabel(
                        isSelected
                            ? L10n.format("snapshot.deselect", snapshot.name)
                            : L10n.format("snapshot.select", snapshot.name)
                    )
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                        .frame(width: 19, height: 24)
                        .accessibilityLabel(L10n.text("snapshot.protected_hint"))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(snapshot.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(iSnapNukeTheme.foreground)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        SafetyBadge(safety: item.safety)
                    }

                    HStack(spacing: 6) {
                        SourceBadge(source: item.source)
                        Text(snapshot.rawUUID.prefix(8))
                            .font(.caption.monospaced())
                            .foregroundStyle(iSnapNukeTheme.mutedForeground)
                    }

                    if isSelectable {
                        Label(
                            L10n.format(
                                "size.estimated_reclaimable",
                                L10n.byteCount(snapshot.privateSizeBytes)
                            ),
                            systemImage: "externaldrive.badge.checkmark"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(iSnapNukeTheme.accent)
                    }

                    if isForceDeletionEnabled && !item.safety.isDeletable && isSelectable {
                        Label(
                            L10n.text("snapshot.force_selectable"),
                            systemImage: "exclamationmark.shield.fill"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(iSnapNukeTheme.destructive)
                    }

                    if case let .protected(reasons) = item.safety, let reason = reasons.first {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(iSnapNukeTheme.mutedForeground)
                            .lineLimit(2)
                    }

                    if let operationDetail {
                        HStack(alignment: .top, spacing: 5) {
                            if operationDetail.icon == "progress.indicator" {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(operationDetail.color)
                            } else {
                                Image(systemName: operationDetail.icon)
                                    .foregroundStyle(operationDetail.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(operationDetail.title)
                                    .foregroundStyle(operationDetail.color)
                                if let message = operationDetail.message, !message.isEmpty {
                                    Text(message)
                                        .foregroundStyle(iSnapNukeTheme.mutedForeground)
                                        .lineLimit(2)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .font(.caption.weight(.medium))
                        .transition(.opacity)
                    }
                }
            }

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Label(
                    isExpanded ? L10n.text("snapshot.details_hide") : L10n.text("snapshot.details_show"),
                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(iSnapNukeTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.text("snapshot.details_hint"))

            if isExpanded {
                SnapshotMetadata(snapshot: snapshot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            isSucceeded
                ? iSnapNukeTheme.accent.opacity(0.12)
                : (isSelected ? iSnapNukeTheme.primary.opacity(0.12) : iSnapNukeTheme.card),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSucceeded
                        ? iSnapNukeTheme.accent
                        : (isSelected ? iSnapNukeTheme.primary : iSnapNukeTheme.border),
                    lineWidth: isSelected || isSucceeded ? 1.5 : 1
                )
        }
        .opacity(isSucceeded ? 0.82 : 1)
        .transition(
            .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
        )
        .animation(.snappy(duration: rowAnimationDuration), value: operationState)
    }
}

private struct SafetyBadge: View {
    let safety: SnapshotSafety

    var body: some View {
        let isDeletable = safety.isDeletable
        Text(safety.localizedStatus)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isDeletable ? iSnapNukeTheme.accentForeground : iSnapNukeTheme.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isDeletable ? iSnapNukeTheme.accent : iSnapNukeTheme.muted, in: Capsule())
            .accessibilityLabel(safety.localizedStatus)
    }
}

private struct SourceBadge: View {
    let source: SnapshotSource

    var body: some View {
        Text(source.localizedName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(iSnapNukeTheme.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(iSnapNukeTheme.muted, in: Capsule())
    }
}

private struct SnapshotMetadata: View {
    let snapshot: APFSSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            MetadataLine(label: L10n.text("metadata.uuid"), value: snapshot.rawUUID)
            MetadataLine(label: L10n.text("metadata.xid"), value: String(snapshot.xid))
            MetadataLine(label: L10n.text("metadata.purgeable"), value: snapshot.purgeable ? L10n.text("value.yes") : L10n.text("value.no"))
            MetadataLine(label: L10n.text("metadata.private_size"), value: L10n.byteCount(snapshot.privateSizeBytes))
            MetadataLine(label: L10n.text("metadata.limits_shrink"), value: snapshot.limitingContainerShrink ? L10n.text("value.yes") : L10n.text("value.no"))
        }
        .padding(10)
        .background(iSnapNukeTheme.muted, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct MetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)
                .frame(width: 105, alignment: .leading)
            Text(value)
                .foregroundStyle(iSnapNukeTheme.foreground)
                .textSelection(.enabled)
                .lineLimit(2)
        }
        .font(.caption)
    }
}

private struct PanelFooter: View {
    let selectionCount: Int
    let selectedPrivateSizeBytes: Int64?
    let isDeleting: Bool
    let deletionProgress: SnapshotDeletionProgress?
    let canDelete: Bool
    let isForceDeletionEnabled: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isDeleting {
                ProgressView()
                    .controlSize(.small)
                Text(
                    deletionProgress.map {
                        L10n.format("footer.processing_progress", $0.current, $0.total)
                    } ?? L10n.text("footer.processing")
                )
                    .font(.caption)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
            } else {
                Text(
                    selectionCount == 0
                        ? L10n.text(
                            isForceDeletionEnabled
                                ? "footer.select_force"
                                : "footer.select_eligible"
                        )
                        : L10n.format(
                            selectionCount == 1 ? "footer.selected" : "footer.selected_plural",
                            selectionCount
                        )
                )
                .font(.caption)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 7) {
                if selectionCount > 0 {
                    Text(
                        L10n.format(
                            "confirm.total_reclaimable",
                            L10n.byteCount(selectedPrivateSizeBytes)
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(iSnapNukeTheme.mutedForeground)
                }

                Button(role: .destructive, action: onDelete) {
                    Label(
                        L10n.format(
                            isForceDeletionEnabled
                                ? (selectionCount == 1
                                    ? "action.force_delete_count"
                                    : "action.force_delete_count_plural")
                                : (selectionCount == 1
                                    ? "action.delete_count"
                                    : "action.delete_count_plural"),
                            selectionCount
                        ),
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(iSnapNukeTheme.destructive)
                .disabled(!canDelete)
                .accessibilityHint(L10n.text("action.delete_hint"))
            }
        }
        .padding(14)
    }
}

private struct ForceDeletionBanner: View {
    let onDisable: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(iSnapNukeTheme.destructive)
            Text(L10n.text("force.mode.banner"))
                .font(.caption)
                .foregroundStyle(iSnapNukeTheme.foreground)
            Spacer(minLength: 0)
            Button(L10n.text("force.mode.disable"), action: onDisable)
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iSnapNukeTheme.destructive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(iSnapNukeTheme.destructive.opacity(0.12))
    }
}

private struct ProgressPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(iSnapNukeTheme.primary)
            Text(L10n.text("progress.loading"))
                .font(.subheadline)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptySnapshotsPanel: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.macro")
                .font(.system(size: 32))
                .foregroundStyle(iSnapNukeTheme.primary)
            Text(L10n.text("empty.title"))
                .font(.headline)
                .foregroundStyle(iSnapNukeTheme.foreground)
            Text(L10n.text("empty.body"))
                .font(.caption)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)
                .multilineTextAlignment(.center)
            Button(L10n.text("action.refresh"), action: onRefresh)
                .buttonStyle(.bordered)
                .tint(iSnapNukeTheme.accent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
