import Foundation

public struct FocusDecision: Equatable, Sendable {
    public var status: DetectionStatus
    public var visualStatus: DetectionStatus
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
        layoutMode: ScreenLayoutMode? = nil,
        language: AppLanguage = .english
    ) -> FocusDecision {
        guard let calibration else {
            currentStatus = .unknown
            return FocusDecision(
                status: .unknown,
                visualStatus: .unknown,
                score: nil,
                message: language.text(.calibrationRequiredShort)
            )
        }

        switch result {
        case .failure(let error):
            activeStreak = 0
            distanceStreak = 0
            missingStreak += 1
            if missingStreak >= sensitivity.missingFaceFramesBeforeInactive {
                currentStatus = .inactive
                inactiveStreak = sensitivity.deactivateFrames
                return FocusDecision(
                    status: .inactive,
                    visualStatus: .inactive,
                    score: nil,
                    message: language.faceDetectionErrorDescription(error)
                )
            }
            currentStatus = .unknown
            return FocusDecision(
                status: .unknown,
                visualStatus: .unknown,
                score: nil,
                message: language.faceDetectionErrorDescription(error)
            )

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
                    visualStatus: .invalidDistance,
                    score: nil,
                    message: language.distanceRatioOutOfRange(distanceRatio)
                )
            }

            distanceStreak = 0
            let playRegionOvershoot = calibration.playRegionOvershoot(feature, layoutMode: layoutMode)
            let playDistance = FaceFeatures.distance(feature, calibration.playCentroid, layoutMode: layoutMode)
            let pauseDistance = calibration.pauseCentroids
                .map { FaceFeatures.distance(feature, $0, layoutMode: layoutMode) }
                .min() ?? Double.greatestFiniteMagnitude
            let score = pauseDistance - playDistance - (playRegionOvershoot * sensitivity.playRegionOvershootPenalty)
            let visualStatus: DetectionStatus
            if score >= sensitivity.activateMargin(for: layoutMode) {
                visualStatus = .active
            } else if score <= sensitivity.deactivateMargin(for: layoutMode) {
                visualStatus = .inactive
            } else {
                visualStatus = currentStatus
            }

            if score >= sensitivity.activateMargin(for: layoutMode) {
                activeStreak += 1
                inactiveStreak = 0
                if activeStreak >= sensitivity.activateFrames {
                    currentStatus = .active
                }
            } else if score <= sensitivity.deactivateMargin(for: layoutMode) {
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
                visualStatus: visualStatus,
                score: score,
                message: language.text(.detectionRunning)
            )
        }
    }
}

private extension Sensitivity {
    func activateMargin(for layoutMode: ScreenLayoutMode?) -> Double {
        switch layoutMode {
        case .horizontal, .vertical:
            return activateMargin + 0.02
        case .mixed:
            return activateMargin + 0.06
        case nil:
            return activateMargin
        }
    }

    func deactivateMargin(for layoutMode: ScreenLayoutMode?) -> Double {
        switch layoutMode {
        case .horizontal, .vertical:
            return deactivateMargin - 0.10
        case .mixed:
            return deactivateMargin - 0.10
        case nil:
            return deactivateMargin
        }
    }
}
