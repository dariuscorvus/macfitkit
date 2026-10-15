import SwiftUI

@main struct PiPFixtureApp: App {
    var body: some Scene {
        WindowGroup("UniversalPiP Testquelle") { FixtureView().frame(minWidth: 400, minHeight: 300) }
    }
}
struct FixtureView: View {
    @State private var running = true
    private let start = Date()
    @State private var frozen = Date()
    var body: some View {
        VStack {
            HStack { Text("OBEN LINKS"); Spacer(); Text("OBEN RECHTS") }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1.0 / 30)) { context in
                VStack {
                    Circle().stroke(.orange, lineWidth: 6).frame(width: 120, height: 120)
                    Text((running ? context.date : frozen).timeIntervalSince(start).formatted(.number.precision(.fractionLength(3))))
                        .font(.system(size: 42, design: .monospaced)).monospacedDigit()
                }
            }
            Button(running ? "Animation pausieren" : "Animation fortsetzen") { frozen = Date(); running.toggle() }
            Spacer()
            HStack { Text("UNTEN LINKS"); Spacer(); Text("UNTEN RECHTS") }
        }.padding(18).foregroundStyle(.white).background(Color(white: 0.1))
    }
}
