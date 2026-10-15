import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 42))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("DockPreview")
                .font(.largeTitle.bold())
            Text("Das Grundgerüst ist bereit.")
            Text("Dock-Hover und Fenstervorschauen folgen im nächsten Schritt.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 440, height: 260)
    }
}

#Preview {
    ContentView()
}
