import Foundation

public enum Sensitivity: String, CaseIterable, Codable, Identifiable, Sendable {
    case conservative
    case balanced
    case fast

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .conservative:
            return "Conservative"
        case .balanced:
            return "Balanced"
        case .fast:
            return "Fast"
        }
    }

    var activateFrames: Int {
        switch self {
        case .conservative:
            return 4
        case .balanced:
            return 3
        case .fast:
            return 2
        }
    }

    var deactivateFrames: Int {
        switch self {
        case .conservative:
            return 3
        case .balanced:
            return 2
        case .fast:
            return 1
        }
    }

    var activateMargin: Double {
        switch self {
        case .conservative:
            return 0.20
        case .balanced:
            return 0.12
        case .fast:
            return 0.06
        }
    }

    var deactivateMargin: Double {
        switch self {
        case .conservative:
            return -0.02
        case .balanced:
            return 0.04
        case .fast:
            return 0.08
        }
    }

    var farDistanceRatio: Double {
        switch self {
        case .conservative:
            return 0.72
        case .balanced:
            return 0.64
        case .fast:
            return 0.56
        }
    }

    var nearDistanceRatio: Double {
        switch self {
        case .conservative:
            return 1.38
        case .balanced:
            return 1.55
        case .fast:
            return 1.70
        }
    }

    var missingFaceFramesBeforeInactive: Int {
        switch self {
        case .conservative:
            return 5
        case .balanced:
            return 4
        case .fast:
            return 3
        }
    }

    var playRegionOvershootPenalty: Double {
        switch self {
        case .conservative:
            return 0.20
        case .balanced:
            return 0.18
        case .fast:
            return 0.15
        }
    }
}
