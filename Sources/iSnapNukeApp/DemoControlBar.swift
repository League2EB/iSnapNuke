#if DEBUG
import SwiftUI
import iSnapNukeLocalization

struct DemoControlBar: View {
    @ObservedObject var controller: DemoModeController

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "testtube.2")
                    .foregroundStyle(iSnapNukeTheme.primary)
                Text(L10n.text("demo.title"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(iSnapNukeTheme.foreground)
                Spacer()
                Button(L10n.text("demo.reset"), action: controller.reset)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(controller.viewModel.isDeleting)
            }

            Text(L10n.text("demo.description"))
                .font(.caption2)
                .foregroundStyle(iSnapNukeTheme.mutedForeground)

            HStack(spacing: 8) {
                Picker(
                    L10n.text("demo.speed"),
                    selection: Binding(
                        get: { controller.speed },
                        set: { controller.selectSpeed($0) }
                    )
                ) {
                    ForEach(DemoDeletionSpeed.allCases) { speed in
                        Text(L10n.text(speed.localizationKey)).tag(speed)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(controller.viewModel.isDeleting)

                Picker(
                    L10n.text("demo.scenario"),
                    selection: Binding(
                        get: { controller.scenario },
                        set: { controller.selectScenario($0) }
                    )
                ) {
                    ForEach(DemoDeletionScenario.allCases) { scenario in
                        Text(L10n.text(scenario.localizationKey)).tag(scenario)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(controller.viewModel.isDeleting)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(iSnapNukeTheme.primary.opacity(0.08))
    }
}
#endif
