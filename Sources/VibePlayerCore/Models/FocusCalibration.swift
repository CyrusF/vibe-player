import Foundation

public enum CalibrationError: LocalizedError, Equatable {
    case notEnoughSamples(String)
    case awayTooClose(index: Int, distance: Double)

    public var errorDescription: String? {
        switch self {
        case .notEnoughSamples(let name):
            return "\(name) needs more valid face samples."
        case .awayTooClose(let index, let distance):
            return "Away sample \(index) is too close to the play sample (\(String(format: "%.2f", distance)))."
        }
    }
}

public struct FocusCalibration: Codable, Equatable, Sendable {
    public static let minimumSamplesPerClip = 5
    public static let minimumAwayDistance = 0.12
    public static let minimumPauseDistance = minimumAwayDistance

    public var version: Int
    public var createdAt: Date
    public var playCentroid: FaceFeatures
    public var pauseCentroids: [FaceFeatures]
    public var distanceMedian: Double
    public var playSampleCount: Int
    public var pauseSampleCounts: [Int]

    public init(
        version: Int = 1,
        createdAt: Date = Date(),
        playCentroid: FaceFeatures,
        pauseCentroids: [FaceFeatures],
        distanceMedian: Double,
        playSampleCount: Int,
        pauseSampleCounts: [Int]
    ) {
        self.version = version
        self.createdAt = createdAt
        self.playCentroid = playCentroid
        self.pauseCentroids = pauseCentroids
        self.distanceMedian = distanceMedian
        self.playSampleCount = playSampleCount
        self.pauseSampleCounts = pauseSampleCounts
    }

    public static func make(playSamples: [FaceFeatures], pauseGroups: [[FaceFeatures]]) throws -> FocusCalibration {
        guard playSamples.count >= minimumSamplesPerClip, let play = FaceFeatures.centroid(playSamples) else {
            throw CalibrationError.notEnoughSamples("Play calibration")
        }

        var pauses: [FaceFeatures] = []
        var pauseCounts: [Int] = []
        for (index, group) in pauseGroups.enumerated() {
            guard group.count >= minimumSamplesPerClip, let centroid = FaceFeatures.centroid(group) else {
                throw CalibrationError.notEnoughSamples("Away calibration \(index + 1)")
            }
            let distance = FaceFeatures.calibrationSeparationDistance(play, centroid)
            guard distance >= minimumAwayDistance else {
                throw CalibrationError.awayTooClose(index: index + 1, distance: distance)
            }
            pauses.append(centroid)
            pauseCounts.append(group.count)
        }

        let distanceValues = (playSamples + pauseGroups.flatMap { $0 })
            .map(\.distanceProxy)
            .sorted()
        let median: Double
        if distanceValues.isEmpty {
            median = play.distanceProxy
        } else if distanceValues.count.isMultiple(of: 2) {
            let upper = distanceValues[distanceValues.count / 2]
            let lower = distanceValues[(distanceValues.count / 2) - 1]
            median = (upper + lower) / 2
        } else {
            median = distanceValues[distanceValues.count / 2]
        }

        return FocusCalibration(
            playCentroid: play,
            pauseCentroids: pauses,
            distanceMedian: max(0.001, median),
            playSampleCount: playSamples.count,
            pauseSampleCounts: pauseCounts
        )
    }
}
