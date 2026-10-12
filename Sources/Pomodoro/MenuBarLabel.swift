import PomodoroCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.status == .idle {
            Image(systemName: "timer")
        } else {
            Text("\(Image(systemName: symbol)) \(TimeFormat.clock(model.remaining))")
                .monospacedDigit()
        }
    }

    private var symbol: String {
        if case .paused = model.status { return "pause.circle" }
        return model.phase?.kind == .rest ? "cup.and.saucer" : "brain.head.profile"
    }
}
