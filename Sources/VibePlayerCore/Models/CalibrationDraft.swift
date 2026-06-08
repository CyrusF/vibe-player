import Foundation

public enum CalibrationClip: Equatable, Sendable {
    case play
    case away(Int)

    public var title: String {
        switch self {
        case .play:
            return "Play"
        case .away(let index):
            return "Away \(index)"
        }
    }
}

public struct CalibrationDraft: Equatable, Sendable {
    public var playSamples: [FaceFeatures] = []
    public var pauseGroups: [[FaceFeatures]] = [[], [], []]

    public init() {}

    public var completedPauseGroups: Int {
        pauseGroups.filter { $0.count >= FocusCalibration.minimumSamplesPerClip }.count
    }

    public var canBuild: Bool {
        playSamples.count >= FocusCalibration.minimumSamplesPerClip && completedPauseGroups == pauseGroups.count
    }

    public mutating func set(samples: [FaceFeatures], for clip: CalibrationClip) {
        switch clip {
        case .play:
            playSamples = samples
        case .away(let index):
            guard pauseGroups.indices.contains(index - 1) else { return }
            pauseGroups[index - 1] = samples
        }
    }

    public func build() throws -> FocusCalibration {
        try FocusCalibration.make(playSamples: playSamples, pauseGroups: pauseGroups)
    }
}
