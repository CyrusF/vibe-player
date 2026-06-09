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
    private static let centerZoneRatio = 0.20

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

    public var recommendedScreenLayoutMode: ScreenLayoutMode {
        Self.recommendedScreenLayoutMode(play: playCentroid, pauses: pauseCentroids)
    }

    func playRegionOvershoot(_ feature: FaceFeatures, layoutMode: ScreenLayoutMode?) -> Double {
        let playPoint = FaceFeatures.layoutAxisPoint(playCentroid)
        let featurePoint = FaceFeatures.layoutAxisPoint(feature)
        let pauseDeltas = pauseCentroids.map { pause in
            let point = FaceFeatures.layoutAxisPoint(pause)
            return LayoutAxisDelta(
                horizontal: point.horizontal - playPoint.horizontal,
                vertical: point.vertical - playPoint.vertical
            )
        }
        let horizontalRadius = max(0.30, pauseDeltas.map { abs($0.horizontal) }.max() ?? 0)
        let verticalRadius = max(0.30, pauseDeltas.map { abs($0.vertical) }.max() ?? 0)
        let horizontalRatio = abs(featurePoint.horizontal - playPoint.horizontal) / (horizontalRadius * 0.38)
        let verticalRatio = abs(featurePoint.vertical - playPoint.vertical) / (verticalRadius * 0.38)

        switch layoutMode {
        case .horizontal:
            return max(0, horizontalRatio - 1)
        case .vertical:
            return max(0, verticalRatio - 1)
        case .mixed, nil:
            return max(0, max(horizontalRatio, verticalRatio) - 1)
        }
    }

    private static func recommendedScreenLayoutMode(play: FaceFeatures, pauses: [FaceFeatures]) -> ScreenLayoutMode {
        let playPoint = FaceFeatures.layoutAxisPoint(play)
        let deltas = pauses.map { pause in
            let point = FaceFeatures.layoutAxisPoint(pause)
            return LayoutAxisDelta(
                horizontal: point.horizontal - playPoint.horizontal,
                vertical: point.vertical - playPoint.vertical
            )
        }
        guard !deltas.isEmpty else { return .mixed }

        let horizontalRadius = max(0.001, deltas.map { abs($0.horizontal) }.max() ?? 0)
        let verticalRadius = max(0.001, deltas.map { abs($0.vertical) }.max() ?? 0)
        let zones = deltas.map {
            LayoutZone(
                delta: $0,
                horizontalCenterThreshold: horizontalRadius * centerZoneRatio,
                verticalCenterThreshold: verticalRadius * centerZoneRatio
            )
        }
        let awayZones = zones.filter { !$0.isCenter }
        guard !awayZones.isEmpty else { return .mixed }

        let nonCenterRows = Set(awayZones.map(\.row).filter { $0 != .center })
        let nonCenterColumns = Set(awayZones.map(\.column).filter { $0 != .center })
        let hasCenterColumn = awayZones.contains { $0.column == .center }
        let hasCenterRow = awayZones.contains { $0.row == .center }
        let hasSideOnlyPoint = awayZones.contains { $0.row == .center && $0.column != .center }
        let hasTopOrBottomOnlyPoint = awayZones.contains { $0.column == .center && $0.row != .center }

        if nonCenterRows.count == 1,
           !hasSideOnlyPoint,
           hasCenterColumn || nonCenterColumns.count >= 2 {
            return .vertical
        }
        if nonCenterColumns.count == 1,
           !hasTopOrBottomOnlyPoint,
           hasCenterRow || nonCenterRows.count >= 2 {
            return .horizontal
        }
        return .mixed
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

private struct LayoutAxisDelta {
    var horizontal: Double
    var vertical: Double
}

private struct LayoutZone {
    enum Band: Hashable {
        case negative
        case center
        case positive
    }

    var column: Band
    var row: Band

    var isCenter: Bool {
        row == .center && column == .center
    }

    init(
        delta: LayoutAxisDelta,
        horizontalCenterThreshold: Double,
        verticalCenterThreshold: Double
    ) {
        column = Self.band(delta.horizontal, threshold: horizontalCenterThreshold)
        row = Self.band(delta.vertical, threshold: verticalCenterThreshold)
    }

    private static func band(_ value: Double, threshold: Double) -> Band {
        if abs(value) <= threshold {
            return .center
        }
        return value < 0 ? .negative : .positive
    }
}
