import XCTest
@testable import VibePlayerCore

final class BrowserVideoControllerTests: XCTestCase {
    func testVideoControlJavaScriptTargetsVideoElementsOnly() {
        let script = BrowserVideoController.videoControlJavaScript(action: .pause)

        XCTAssertTrue(script.contains("querySelectorAll(\"video\")"))
        XCTAssertFalse(script.contains("querySelectorAll(\"audio\")"))
        XCTAssertTrue(script.contains("rect.width >= 160"))
        XCTAssertTrue(script.contains("video.pause()"))
        XCTAssertTrue(script.contains("isPaused: video.paused"))
    }

    func testVideoControlJavaScriptCanQueryPlaybackStatus() {
        let script = BrowserVideoController.videoControlJavaScript(action: .status)

        XCTAssertTrue(script.contains("action === \"status\""))
        XCTAssertTrue(script.contains("video.paused ? \"paused\" : \"playing\""))
    }

    func testPlayJavaScriptReportsStillPausedInsteadOfBlindSuccess() {
        let script = BrowserVideoController.videoControlJavaScript(action: .play)

        XCTAssertTrue(script.contains("play-requested-still-paused"))
        XCTAssertTrue(script.contains(".ytp-play-button"))
        XCTAssertTrue(script.contains("video.play()"))
    }

    func testAppleScriptEscapingKeepsJavaScriptSingleLineSafe() {
        let escaped = BrowserVideoController.escapeAppleScript("const value = \"a\\b\";\nvideo.pause();")

        XCTAssertFalse(escaped.contains("\n"))
        XCTAssertTrue(escaped.contains("\\\"a\\\\b\\\""))
    }
}
