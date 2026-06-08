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
}
