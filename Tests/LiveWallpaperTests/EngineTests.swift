import XCTest
@testable import LiveWallpaper

final class EngineTests: XCTestCase {
    private let global = URL(fileURLWithPath: "/videos/global.mp4")
    private let ext = URL(fileURLWithPath: "/videos/external.mp4")

    func testFallbackToGlobalWhenNoOverride() {
        XCTAssertNil(WallpaperEngine.videoForScreen("1", global: nil, overrides: [:]))
        XCTAssertEqual(WallpaperEngine.videoForScreen("1", global: global, overrides: [:]), global)
    }

    func testOverrideWins() {
        XCTAssertEqual(
            WallpaperEngine.videoForScreen("1", global: global, overrides: ["1": ext]),
            ext
        )
    }

    func testOverrideOnlyAffectsItsScreen() {
        let overrides = ["2": ext]
        XCTAssertEqual(WallpaperEngine.videoForScreen("1", global: global, overrides: overrides), global)
        XCTAssertEqual(WallpaperEngine.videoForScreen("2", global: global, overrides: overrides), ext)
    }

    func testBookmarkRoundTrip() throws {
        // Security-scoped bookmark survives persist/restore cycle
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("lw-test-\(UUID().uuidString).mp4")
        try Data([0x00]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let data = try tmp.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        var stale = false
        let restored = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
        XCTAssertEqual(restored.standardizedFileURL, tmp.standardizedFileURL)
        XCTAssertEqual(restored.lastPathComponent, tmp.lastPathComponent)
    }
}
