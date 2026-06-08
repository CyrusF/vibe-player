import Foundation

public enum BrowserKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case safari
    case chrome
    case edge
    case arc
    case brave

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .safari:
            return "Safari"
        case .chrome:
            return "Google Chrome"
        case .edge:
            return "Microsoft Edge"
        case .arc:
            return "Arc"
        case .brave:
            return "Brave Browser"
        }
    }

    var appleScriptName: String { displayName }

    var isSafari: Bool { self == .safari }
}

public struct PlayerTarget: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var browser: BrowserKind
    public var windowIndex: Int
    public var tabIndex: Int
    public var title: String
    public var url: String
    public var capturedAt: Date

    public init(
        id: UUID = UUID(),
        browser: BrowserKind,
        windowIndex: Int,
        tabIndex: Int,
        title: String,
        url: String,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.browser = browser
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.title = title
        self.url = url
        self.capturedAt = capturedAt
    }
}
