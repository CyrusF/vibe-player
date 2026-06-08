import Foundation

public enum DetectionStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case active
    case inactive
    case unknown
    case invalidDistance

    public var title: String {
        switch self {
        case .active:
            return "Looking at playback screen"
        case .inactive:
            return "Away from playback screen"
        case .unknown:
            return "Waiting for face signal"
        case .invalidDistance:
            return "Face distance out of range"
        }
    }
}
