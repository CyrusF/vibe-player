import Foundation

public struct VideoWatchEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var title: String
    public var url: String
    public var browserName: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        title: String,
        url: String,
        browserName: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.url = url
        self.browserName = browserName
    }

    public var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

public struct VideoWatchDay: Identifiable, Equatable, Sendable {
    public var date: Date
    public var duration: TimeInterval

    public init(date: Date, duration: TimeInterval) {
        self.date = date
        self.duration = duration
    }

    public var id: Date { date }
}

public struct ActiveVideoWatchSession: Equatable, Sendable {
    public var startedAt: Date
    public var title: String
    public var url: String
    public var browserName: String

    public init(startedAt: Date, title: String, url: String, browserName: String) {
        self.startedAt = startedAt
        self.title = title
        self.url = url
        self.browserName = browserName
    }
}
