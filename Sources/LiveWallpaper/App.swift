import SwiftUI

@main
struct LiveWallpaperApp: App {
    @StateObject private var engine = WallpaperEngine.shared

    var body: some Scene {
        MenuBarExtra("Live Wallpaper", systemImage: "play.rectangle.fill") {
            MenuContent(engine: engine)
        }

        Window("Live Wallpaper Settings", id: "settings") {
            SettingsView()
                .frame(width: 420, height: 340)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuContent: View {
    @ObservedObject var engine: WallpaperEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(engine.videoURL?.lastPathComponent ?? "No video loaded")
                .font(.headline).lineLimit(1).truncationMode(.middle)
            Button(engine.isPlaying ? "Pause" : "Play") { engine.toggle() }
                .disabled(engine.videoURL == nil && engine.screenVideos.isEmpty)
            Button("Choose 4K Video…") { engine.chooseVideo() }
            HStack {
                Text("Volume")
                Slider(value: $engine.volume, in: 0...1)
                    .frame(width: 120)
            }
            Divider()
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .keyboardShortcut(",")
            Divider()
            Text("\(NSScreen.screens.count) display(s) • HW decode • muted = lowest CPU")
                .font(.caption).foregroundColor(.secondary)
            Button("Quit") { engine.quit() }
        }
        .padding(10).frame(width: 260)
    }
}

struct SettingsView: View {
    @ObservedObject var engine = WallpaperEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All displays").font(.headline)
                Spacer()
                Text(engine.videoURL?.lastPathComponent ?? "None")
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Button("Choose…") { engine.chooseVideo() }
            }
            .padding(.vertical, 10)
            Divider()
            Text("Per-display override")
                .font(.subheadline).foregroundColor(.secondary)
                .padding(.top, 12)
            ForEach(NSScreen.screens, id: \.self) { screen in
                HStack {
                    Text(screen.localizedName)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if engine.hasOverride(for: screen) {
                        Text(engine.videoURL(for: screen)?.lastPathComponent ?? "")
                            .font(.caption).foregroundColor(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Button("Use Global") { engine.clearOverride(for: screen) }
                            .buttonStyle(.link)
                    }
                    Button("Choose…") { engine.chooseVideo(for: screen) }
                }
                .padding(.vertical, 8)
                Divider()
            }
            Spacer()
        }
        .padding(16)
    }
}
