import Foundation

public final class PreferencesStore {
    private enum Key {
        static let calibration = "calibration"
        static let target = "target"
        static let selectedDisplayID = "selectedDisplayID"
        static let sensitivity = "sensitivity"
        static let screenLayoutMode = "screenLayoutMode"
        static let mediaFallback = "mediaFallback"
        static let completedOnboarding = "completedOnboarding"
        static let appLanguage = "appLanguage"
        static let watchHistory = "watchHistory"
    }

    private let defaults: UserDefaults
    private let preferredLanguages: [String]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
    }

    public var calibration: FocusCalibration? {
        get { decode(FocusCalibration.self, forKey: Key.calibration) }
        set { encode(newValue, forKey: Key.calibration) }
    }

    public var target: PlayerTarget? {
        get { decode(PlayerTarget.self, forKey: Key.target) }
        set { encode(newValue, forKey: Key.target) }
    }

    public var selectedDisplayID: UInt32? {
        get {
            let value = defaults.integer(forKey: Key.selectedDisplayID)
            return value == 0 ? nil : UInt32(value)
        }
        set {
            if let newValue {
                defaults.set(Int(newValue), forKey: Key.selectedDisplayID)
            } else {
                defaults.removeObject(forKey: Key.selectedDisplayID)
            }
        }
    }

    public var sensitivity: Sensitivity {
        get {
            guard let raw = defaults.string(forKey: Key.sensitivity),
                  let value = Sensitivity(rawValue: raw) else {
                return .balanced
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.sensitivity) }
    }

    public var screenLayoutMode: ScreenLayoutMode? {
        get {
            guard let raw = defaults.string(forKey: Key.screenLayoutMode) else {
                return nil
            }
            return ScreenLayoutMode(rawValue: raw)
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.screenLayoutMode)
            } else {
                defaults.removeObject(forKey: Key.screenLayoutMode)
            }
        }
    }

    public var mediaFallbackEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.mediaFallback) != nil else {
                return true
            }
            return defaults.bool(forKey: Key.mediaFallback)
        }
        set { defaults.set(newValue, forKey: Key.mediaFallback) }
    }

    public var completedOnboarding: Bool {
        get { defaults.bool(forKey: Key.completedOnboarding) }
        set { defaults.set(newValue, forKey: Key.completedOnboarding) }
    }

    public var appLanguage: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: Key.appLanguage),
                  let language = AppLanguage(rawValue: raw) else {
                let language = AppLanguage.defaultLanguage(preferredLanguages: preferredLanguages)
                defaults.set(language.rawValue, forKey: Key.appLanguage)
                return language
            }
            return language
        }
        set { defaults.set(newValue.rawValue, forKey: Key.appLanguage) }
    }

    public var watchHistory: [VideoWatchEvent] {
        get { decode([VideoWatchEvent].self, forKey: Key.watchHistory) ?? [] }
        set { encode(newValue, forKey: Key.watchHistory) }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
