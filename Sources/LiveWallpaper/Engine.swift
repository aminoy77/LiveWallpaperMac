import AppKit
import AVKit
import Combine

/// One AVPlayer per screen, hardware-decoded, looped. No transcoding, no webviews.
final class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine()

    @Published var videoURL: URL? {
        didSet { if !isRestoring { if let u = videoURL { saveBookmark(u) } ; play() } }
    }
    /// Per-display override keyed by CGDirectDisplayID. Missing key → global videoURL.
    @Published var screenVideos: [String: URL] = [:] {
        didSet { guard !isRestoring else { return }; saveScreenBookmarks(); play() }
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
    private var isRestoring = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        restoreBookmark()
        observeSystem()
    }

    // MARK: - Public

    /// Stable display identifier (CGDirectDisplayID, lives across spaces/rebuilds).
    static func key(for screen: NSScreen) -> String {
        String((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int) ?? 0)
    }

    /// Pure mapping, extracted for unit testing.
    static func videoForScreen(_ key: String, global: URL?, overrides: [String: URL]) -> URL? {
        overrides[key] ?? global
    }

    func videoURL(for screen: NSScreen) -> URL? {
        Self.videoForScreen(Self.key(for: screen), global: videoURL, overrides: screenVideos)
    }

    func hasOverride(for screen: NSScreen) -> Bool {
        screenVideos[Self.key(for: screen)] != nil
    }

    func chooseVideo(for screen: NSScreen? = nil) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let url = p.url else { return }
        // ponytail: security-scoped bookmark only, no file copy (4K files stay in place)
        if let screen = screen {
            screenVideos[Self.key(for: screen)] = url
        } else {
            videoURL = url
        }
    }

    func clearOverride(for screen: NSScreen) {
        screenVideos.removeValue(forKey: Self.key(for: screen))
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
        guard !userPaused, videoURL != nil || !screenVideos.isEmpty else { return }
        players.forEach { $0.play() }
        isPlaying = true
    }

    func quit() { autoPause(); NSApp.terminate(nil) }

    // MARK: - Core

    /// Builds one panel+player per screen. Each screen plays its override video,
    /// falling back to the global videoURL; screens with no video anywhere get none.
    private func play() {
        teardown()
        var startedAny = false
        for screen in NSScreen.screens {
            guard let url = videoURL(for: screen) else { continue }
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
            startedAny = true
        }
        guard startedAny else { isPlaying = false; return }
        // ponytail: autostart avoids re-seek cost
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
        ) { [weak self] _ in self?.play() }
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

    private func saveScreenBookmarks() {
        var dict: [String: Data] = [:]
        for (key, url) in screenVideos {
            if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                dict[key] = data
            }
        }
        UserDefaults.standard.set(dict, forKey: "screenBookmarks")
    }

    private func restoreBookmark() {
        volume = UserDefaults.standard.object(forKey: "volume") as? Float ?? 0
        var restored: [String: URL] = [:]
        if let dict = UserDefaults.standard.dictionary(forKey: "screenBookmarks") as? [String: Data] {
            for (key, data) in dict {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                    _ = url.startAccessingSecurityScopedResource()
                    restored[key] = url
                }
            }
        }
        guard let data = UserDefaults.standard.data(forKey: "videoBookmark") else {
            if !restored.isEmpty {
                isRestoring = true
                screenVideos = restored
                isRestoring = false
                DispatchQueue.main.async { [weak self] in self?.play() }
            }
            return
        }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            _ = url.startAccessingSecurityScopedResource()
            isRestoring = true
            screenVideos = restored
            isRestoring = false
            // Defer play until app finished launching (screens exist)
            DispatchQueue.main.async { [weak self] in self?.videoURL = url }
        } else if !restored.isEmpty {
            isRestoring = true
            screenVideos = restored
            isRestoring = false
            DispatchQueue.main.async { [weak self] in self?.play() }
        }
    }
}
