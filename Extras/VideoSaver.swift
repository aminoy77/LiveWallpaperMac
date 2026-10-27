import ScreenSaver
import AVKit

// DeskForge video ScreenSaver — plays your current DeskForge video on idle/lock.
// This is the only legit way to get video onto the locked screen: macOS runs
// .saver bundles via ScreenSaverEngine, which also draws over the login window.
//
// Build: Xcode → macOS → ScreenSaver bundle → add this file → build →
// double-click the .saver to install → System Settings → Screen Saver → DeskForge.
//
// Bridge: a .saver cannot read the app's UserDefaults domain, so DeskForge also
// saves the plain video path ("videoPath") to its own prefs plist, which we read here.
final class VideoSaverView: ScreenSaverView {
    private var player: AVPlayer?
    private lazy var saverLayer: AVPlayerLayer = {
        let l = AVPlayerLayer()
        l.videoGravity = .resizeAspectFill
        return l
    }()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        saverLayer.frame = bounds
        saverLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer = saverLayer
        animationTimeInterval = 1
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func startAnimation() {
        super.startAnimation()
        guard let path = videoPath(), FileManager.default.fileExists(atPath: path) else { return }
        let p = AVPlayer(url: URL(fileURLWithPath: path))
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: p.currentItem, queue: .main) { [weak p] _ in
            p?.seek(to: .zero)
            p?.play()
        }
        p.isMuted = true
        saverLayer.player = p
        p.play()
        player = p
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
        player = nil
    }

    private func videoPath() -> String? {
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.local.livewallpaper.plist")
        guard let d = NSDictionary(contentsOf: plist) as? [String: Any] else { return nil }
        return d["videoPath"] as? String
    }
}
