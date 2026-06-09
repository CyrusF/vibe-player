import XCTest
@testable import VibePlayerCore

final class PreferencesStoreTests: XCTestCase {
    func testMediaKeyFallbackDefaultsToEnabled() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults)

        XCTAssertTrue(store.mediaFallbackEnabled)
    }

    func testMediaKeyFallbackPreservesExplicitDisabledPreference() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults)
        store.mediaFallbackEnabled = false

        XCTAssertFalse(store.mediaFallbackEnabled)
    }

    func testScreenLayoutModeDefaultsToUnselected() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults)

        XCTAssertNil(store.screenLayoutMode)
    }

    func testScreenLayoutModePersistsExplicitPreference() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults)
        store.screenLayoutMode = .vertical

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.screenLayoutMode, .vertical)
    }

    @MainActor
    func testAppStoreMigratesExistingCalibrationToRecommendedScreenLayoutMode() throws {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = PreferencesStore(defaults: defaults)
        let calibration = try FocusCalibration.make(
            playSamples: samples(near: feature(yaw: 0.22, pupilOffsetX: 0.05)),
            pauseGroups: [
                samples(near: feature(yaw: -0.24, pupilOffsetX: -0.06)),
                samples(near: feature(yaw: -0.28, pupilOffsetX: -0.07)),
                samples(near: feature(yaw: -0.20, pupilOffsetX: -0.05))
            ]
        )
        preferences.calibration = calibration

        let appStore = AppStore(preferences: preferences)

        XCTAssertEqual(appStore.screenLayoutMode, .horizontal)
        XCTAssertTrue(appStore.shouldShowScreenLayoutModeLaunchNotice)
        XCTAssertEqual(preferences.screenLayoutMode, .horizontal)
    }

    func testLanguageDefaultsToChineseWhenSystemLanguageIsChinese() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults, preferredLanguages: ["zh-Hans-US", "en-US"])

        XCTAssertEqual(store.appLanguage, .chinese)
    }

    func testLanguageDefaultsToEnglishWhenSystemLanguageIsNotChinese() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults, preferredLanguages: ["ja-JP", "zh-Hans-US"])

        XCTAssertEqual(store.appLanguage, .english)
    }

    func testLanguageDefaultIsStoredAfterFirstRead() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstLaunch = PreferencesStore(defaults: defaults, preferredLanguages: ["zh-Hans-US"])
        XCTAssertEqual(firstLaunch.appLanguage, .chinese)

        let laterLaunch = PreferencesStore(defaults: defaults, preferredLanguages: ["en-US"])
        XCTAssertEqual(laterLaunch.appLanguage, .chinese)
    }

    func testLanguagePreservesExplicitPreference() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PreferencesStore(defaults: defaults, preferredLanguages: ["zh-Hans-US"])
        store.appLanguage = .english

        let reloaded = PreferencesStore(defaults: defaults, preferredLanguages: ["zh-Hans-US"])
        XCTAssertEqual(reloaded.appLanguage, .english)
    }

    func testWatchHistoryPersistsEvents() {
        let suiteName = "VibePlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let startedAt = Date(timeIntervalSince1970: 1_800)
        let event = VideoWatchEvent(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(600),
            title: "Focus Break",
            url: "https://example.com/video",
            browserName: "Safari"
        )

        let store = PreferencesStore(defaults: defaults)
        store.watchHistory = [event]

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.watchHistory, [event])
    }

    private func samples(near base: FaceFeatures) -> [FaceFeatures] {
        (0..<6).map { index in
            feature(
                yaw: base.yaw + (Double(index) * 0.001),
                pitch: base.pitch,
                roll: base.roll,
                faceCenterX: base.faceCenterX,
                faceCenterY: base.faceCenterY,
                faceHeight: base.faceHeight,
                eyeDistance: base.eyeDistance,
                leftEyeOpenness: base.leftEyeOpenness,
                rightEyeOpenness: base.rightEyeOpenness,
                pupilOffsetX: base.pupilOffsetX,
                pupilOffsetY: base.pupilOffsetY
            )
        }
    }

    private func feature(
        yaw: Double,
        pitch: Double = 0.04,
        roll: Double = 0.01,
        faceCenterX: Double = 0.52,
        faceCenterY: Double = 0.54,
        faceHeight: Double = 0.18,
        eyeDistance: Double = 0.072,
        leftEyeOpenness: Double = 0.29,
        rightEyeOpenness: Double = 0.30,
        pupilOffsetX: Double,
        pupilOffsetY: Double = 0.01
    ) -> FaceFeatures {
        FaceFeatures(
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            faceCenterX: faceCenterX,
            faceCenterY: faceCenterY,
            faceHeight: faceHeight,
            eyeDistance: eyeDistance,
            leftEyeOpenness: leftEyeOpenness,
            rightEyeOpenness: rightEyeOpenness,
            pupilOffsetX: pupilOffsetX,
            pupilOffsetY: pupilOffsetY
        )
    }
}
