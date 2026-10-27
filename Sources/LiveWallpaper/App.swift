import SwiftUI

@main
struct LiveWallpaperApp: App {
    @StateObject private var engine = WallpaperEngine.shared

    var body: some Scene {
        MenuBarExtra("Live Wallpaper", systemImage: "play.rectangle.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text(engine.videoURL?.lastPathComponent ?? "No video loaded")
                    .font(.headline).lineLimit(1).truncationMode(.middle)
                Button(engine.isPlaying ? "Pause" : "Play") { engine.toggle() }
                    .disabled(engine.videoURL == nil)
                Button("Choose 4K Video…") { engine.chooseVideo() }
                Divider()
                HStack {
                    Text("Volume")
                    Slider(value: $engine.volume, in: 0...1)
                        .frame(width: 120)
                }
                Toggle("Pause on fullscreen", isOn: $engine.pauseOnFullscreen)
                Toggle("Pause on Low Power Mode", isOn: $engine.pauseOnBattery)
                Divider()
                Text("\(NSScreen.screens.count) display(s) • HW decode • muted = lowest CPU")
                    .font(.caption).foregroundColor(.secondary)
                Button("Quit") { engine.quit() }
            }
            .padding(10).frame(width: 260)
        }
    }
}
