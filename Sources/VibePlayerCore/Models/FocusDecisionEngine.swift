import Foundation

public struct FocusDecision: Equatable, Sendable {
    public var status: DetectionStatus
    public var score: Double?
    public var message: String
}

public struct FocusDecisionEngine: Sendable {
    private var activeStreak = 0
    private var inactiveStreak = 0
    private var missingStreak = 0
    private var distanceStreak = 0
    private var currentStatus: DetectionStatus = .unknown

    public init() {}

    public mutating func reset() {
        activeStreak = 0
        inactiveStreak = 0
        missingStreak = 0
        distanceStreak = 0
        currentStatus = .unknown
    }

    public mutating func update(
        feature result: Result<FaceFeatures, FaceDetectionError>,
        calibration: FocusCalibration?,
        sensitivity: Sensitivity,
        language: AppLanguage = .english
    ) -> FocusDecision {
        guard let calibration else {
            currentStatus = .unknown
            return FocusDecision(status: .unknown, score: nil, message: language.text(.calibrationRequiredShort))
        }

        switch result {
        case .failure(let error):
            activeStreak = 0
            distanceStreak = 0
            missingStreak += 1
            if missingStreak >= sensitivity.missingFaceFramesBeforeInactive {
                currentStatus = .inactive
                inactiveStreak = sensitivity.deactivateFrames
                return FocusDecision(status: .inactive, score: nil, message: language.faceDetectionErrorDescription(error))
            }
            currentStatus = .unknown
            return FocusDecision(status: .unknown, score: nil, message: language.faceDetectionErrorDescription(error))

        case .success(let feature):
            missingStreak = 0
            let distanceRatio = feature.distanceProxy / calibration.distanceMedian
            if distanceRatio < sensitivity.farDistanceRatio || distanceRatio > sensitivity.nearDistanceRatio {
                activeStreak = 0
                inactiveStreak += 1
                distanceStreak += 1
                if inactiveStreak >= sensitivity.deactivateFrames {
                    currentStatus = .invalidDistance
                }
                return FocusDecision(
                    status: currentStatus,
                    score: nil,
                    message: language.distanceRatioOutOfRange(distanceRatio)
                )
            }

            distanceStreak = 0
            let playDistance = FaceFeatures.distance(feature, calibration.playCentroid)
            let pauseDistance = calibration.pauseCentroids
                .map { FaceFeatures.distance(feature, $0) }
                .min() ?? Double.greatestFiniteMagnitude
            let score = pauseDistance - playDistance

            if score >= sensitivity.activateMargin {
                activeStreak += 1
                inactiveStreak = 0
                if activeStreak >= sensitivity.activateFrames {
                    currentStatus = .active
                }
            } else if score <= sensitivity.deactivateMargin {
                inactiveStreak += 1
                activeStreak = 0
                if inactiveStreak >= sensitivity.deactivateFrames {
                    currentStatus = .inactive
                }
            } else {
                activeStreak = max(0, activeStreak - 1)
                inactiveStreak = max(0, inactiveStreak - 1)
            }

            return FocusDecision(
                status: currentStatus,
                score: score,
                message: language.focusScore(score)
            )
        }
    }
}
