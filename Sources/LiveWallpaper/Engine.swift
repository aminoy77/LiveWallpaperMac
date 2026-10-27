import AppKit
import AVKit
import Combine

/// One AVPlayer per screen, hardware-decoded, looped. No transcoding, no webviews.
final class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine()

    @Published var videoURL: URL? {
        didSet { if let u = videoURL { saveBookmark(u); play(url: u) } }
    }
    @Published var isPlaying = false
    @Published var volume: Float = 0 { // muted by default = less CPU
        didSet { if volume != oldValue { players.forEach { $0.volume = volume } } }
    }
    @Published var pauseOnBattery = true
    @Published var pauseOnFullscreen = true

    private var players: [AVPlayer] = []
    private var windows: [NSWindow] = []
    private var loopObservers: [NSObjectProtocol] = []
    private var userPaused = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        restoreBookmark()
        observeSystem()
    }

    // MARK: - Public

    func chooseVideo() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        if p.runModal() == .OK, let url = p.url {
            // ponytail: security-scoped bookmark only, no file copy (4K files stay in place)
            videoURL = url
        }
    }

    func toggle() { isPlaying ? pause(user: true) : resume() }

    func pause(user: Bool = false) {
        if user { userPaused = true }
        players.forEach { $0.pause() }
        isPlaying = false
    }

    func resume() {
        guard videoURL != nil else { return }
        userPaused = false
        players.forEach { $0.play() }
        isPlaying = true
    }

    private func autoPause() {
        guard !userPaused else { return }
        players.forEach { $0.pause() }
        isPlaying = false
    }

    private func autoResume() {
        guard !userPaused, videoURL != nil else { return }
        players.forEach { $0.play() }
        isPlaying = true
    }

    func quit() { autoPause(); NSApp.terminate(nil) }

    // MARK: - Core

    private func play(url: URL) {
        teardown()
        for screen in NSScreen.screens {
            let player = AVPlayer(url: url)
            player.volume = volume
            player.actionAtItemEnd = .none
            // Seamless loop, no re-buffer
            let token = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem, queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            loopObservers.append(token)
            // HW decode: no filters, direct layer. Bounds (not screen.frame: origin differs per monitor).
            let bounds = CGRect(origin: .zero, size: screen.frame.size)
            let layer = AVPlayerLayer(player: player)
            layer.frame = bounds
            layer.videoGravity = .resizeAspectFill
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

            // No `screen:` param: it treats contentRect as screen-local and doubles
            // the offset on non-main displays (window lands off-screen). Global rect
            // + no screen arg assigns the panel to the display it overlaps.
            let w = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.isOpaque = false
            w.backgroundColor = .black
            w.ignoresMouseEvents = true
            w.contentView?.layer = layer
            w.contentView?.wantsLayer = true
            w.orderFrontRegardless()

            players.append(player)
            windows.append(w)
        }
        // ponytail: autostart avoids re-seek cost; players share one asset
        players.forEach { $0.play() }
        isPlaying = true
    }

    private func teardown() {
        loopObservers.forEach(NotificationCenter.default.removeObserver)
        loopObservers.removeAll()
        autoPause()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        players.removeAll()
    }

    // MARK: - Low-resource guards

    private func observeSystem() {
        // Pause when any app goes fullscreen (saves GPU/battery)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: nil, queue: .main
        ) { [weak self] _ in if self?.pauseOnFullscreen == true { self?.autoPause() } }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.autoResume() }
        // Low Power Mode actually gates playback now (toggle was dead before)
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let s = self, s.pauseOnBattery else { return }
            if ProcessInfo.processInfo.isLowPowerModeEnabled { s.autoPause() }
            else { s.autoResume() }
        }
        // Rebuild windows when monitors change
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in if let u = self?.videoURL { self?.play(url: u) } }
        // Screensaver / lock pauses decode
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.pause() }
    }

    // MARK: - Persistence (bookmark survives reboot)

    private func saveBookmark(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: "videoBookmark")
            // ponytail: plain path for VideoSaver.saver (savers can't read our defaults domain)
            UserDefaults.standard.set(url.path, forKey: "videoPath")
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }

    private func restoreBookmark() {
        volume = UserDefaults.standard.object(forKey: "volume") as? Float ?? 0
        guard let data = UserDefaults.standard.data(forKey: "videoBookmark") else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            _ = url.startAccessingSecurityScopedResource()
            // Defer play until app finished launching (screens exist)
            DispatchQueue.main.async { [weak self] in self?.videoURL = url }
        }
    }
}
