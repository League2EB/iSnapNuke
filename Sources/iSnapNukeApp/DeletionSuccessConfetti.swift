import ConfettiSwiftUI
import SwiftUI

struct DeletionSuccessConfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = 0
    @State private var hasTriggered = false

    var body: some View {
        Color.clear
            .confettiCannon(
                trigger: $trigger,
                num: 90,
                confettis: [
                    .shape(.triangle),
                    .shape(.square),
                    .shape(.slimRectangle),
                ],
                colors: [
                    iSnapNukeTheme.primary,
                    iSnapNukeTheme.accent,
                    Color(lightHex: 0xF4B740, darkHex: 0xF8C65D),
                    Color(lightHex: 0x63B99A, darkHex: 0x75C9AA),
                ],
                confettiSize: 10,
                rainHeight: 360,
                fadesOut: true,
                opacity: 0.95,
                openingAngle: .degrees(0),
                closingAngle: .degrees(360),
                radius: 210,
                repetitions: 1,
                hapticFeedback: false
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion, !hasTriggered else { return }

                hasTriggered = true
                DispatchQueue.main.async {
                    trigger += 1
                }
            }
    }
}
