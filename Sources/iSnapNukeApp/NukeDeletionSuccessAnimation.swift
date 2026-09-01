import AppKit
import Lottie
import SwiftUI

struct NukeDeletionSuccessAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !reduceMotion {
                NukeDeletionSuccessLottieView()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct NukeDeletionSuccessLottieView: NSViewRepresentable {
    func makeNSView(context _: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(
            name: "NukeDeletionSuccess",
            bundle: .module,
            animationCache: nil
        )
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.currentProgress = 0
        animationView.play(
            fromProgress: 0,
            toProgress: 1,
            loopMode: .playOnce
        )
        return animationView
    }

    func updateNSView(_: LottieAnimationView, context _: Context) {}
}
