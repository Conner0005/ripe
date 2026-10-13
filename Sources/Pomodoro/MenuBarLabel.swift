import PomodoroCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let tomato = Image(nsImage: TomatoImage.image(for: state)).renderingMode(.original)
        if model.status == .idle {
            tomato
        } else {
            Text("\(tomato) \(TimeFormat.clock(model.remaining))")
                .monospacedDigit()
        }
    }

    private var state: TomatoState {
        switch model.status {
        case .idle: return .idle
        case .paused: return .paused
        case .running:
            guard let phase = model.phase, phase.kind == .work, phase.duration > 0 else { return .rest }
            return .ripening(Ripeness.step(progress: 1 - model.remaining / phase.duration))
        }
    }
}
