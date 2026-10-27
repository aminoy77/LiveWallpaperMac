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
                .frame(minWidth: 440, minHeight: 340)
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

            // MARK: Playlist & rotation
            Text("Playlist & rotation")
                .font(.subheadline).foregroundColor(.secondary)
                .padding(.top, 12)
            ForEach(engine.playlist, id: \.self) { url in
                HStack {
                    Image(systemName: "play.rectangle")
                        .foregroundColor(.secondary)
                    Text(url.lastPathComponent)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Remove") { engine.removeFromPlaylist(url) }
                        .buttonStyle(.link)
                }
            }
            Button("Add to Playlist…") { engine.addToPlaylist() }
                .padding(.vertical, 6)

            Picker("Rotate", selection: $engine.rotationMode) {
                ForEach(WallpaperEngine.RotationMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .padding(.vertical, 6)

            if engine.rotationMode == .everyN {
                HStack {
                    Stepper("Every \(engine.rotationMinutes) min",
                            value: $engine.rotationMinutes, in: 1...240)
                    Spacer()
                }
            }

            if engine.rotationMode == .dayNight {
                HStack {
                    Text("Day").frame(width: 40, alignment: .leading)
                    Text(engine.dayVideo?.lastPathComponent ?? "None")
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Button("Choose…") { chooseSlot { engine.dayVideo = $0 } }
                    Spacer()
                    Text("from").font(.caption).foregroundColor(.secondary)
                    Stepper(value: $engine.dayStartHour, in: 0...23) {
                        Text(String(format: "%02d:00", engine.dayStartHour))
                            .font(.callout).monospacedDigit()
                    }
                }
                HStack {
                    Text("Night").frame(width: 40, alignment: .leading)
                    Text(engine.nightVideo?.lastPathComponent ?? "None")
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Button("Choose…") { chooseSlot { engine.nightVideo = $0 } }
                    Spacer()
                    Text("from").font(.caption).foregroundColor(.secondary)
                    Stepper(value: $engine.nightStartHour, in: 0...23) {
                        Text(String(format: "%02d:00", engine.nightStartHour))
                            .font(.callout).monospacedDigit()
                    }
                }
            }
            Spacer()
        }
        .padding(16)
    }

    private func chooseSlot(_ set: @escaping (URL) -> Void) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        p.allowsMultipleSelection = false
        if p.runModal() == .OK, let url = p.url { set(url) }
    }
}
