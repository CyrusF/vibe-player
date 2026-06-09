import XCTest
@testable import VibePlayerCore

final class FocusDecisionEngineTests: XCTestCase {
    func testCalibrationRejectsAwayClipThatIsTooCloseToPlay() throws {
        let play = samples(near: feature(yaw: 0.20, pupilOffsetX: 0.05))
        let closeAway = samples(near: feature(yaw: 0.21, pupilOffsetX: 0.05))

        XCTAssertThrowsError(try FocusCalibration.make(
            playSamples: play,
            pauseGroups: [closeAway, closeAway, closeAway]
        )) { error in
            guard case CalibrationError.awayTooClose = error else {
                return XCTFail("Expected awayTooClose, got \(error)")
            }
        }
    }

    func testCalibrationAcceptsVerticalAwayGaze() throws {
        let play = feature(yaw: 0.20, pitch: 0.02, pupilOffsetX: 0.04, pupilOffsetY: 0.00)
        let upwardAway = feature(yaw: 0.20, pitch: 0.04, pupilOffsetX: 0.04, pupilOffsetY: 0.08)
        let sideAway = feature(yaw: -0.22, pitch: 0.03, pupilOffsetX: -0.04, pupilOffsetY: 0.00)

        XCTAssertNoThrow(try FocusCalibration.make(
            playSamples: samples(near: play),
            pauseGroups: [
                samples(near: sideAway),
                samples(near: feature(yaw: -0.26, pupilOffsetX: -0.05)),
                samples(near: upwardAway)
            ]
        ))
    }

    func testCalibrationRecommendsHorizontalLayoutForSidewaysAwaySamples() throws {
        let play = feature(yaw: 0.20, pitch: 0.04, pupilOffsetX: 0.05)
        let calibration = try FocusCalibration.make(
            playSamples: samples(near: play),
            pauseGroups: [
                samples(near: feature(yaw: -0.24, pitch: 0.04, pupilOffsetX: -0.06)),
                samples(near: feature(yaw: -0.28, pitch: 0.04, pupilOffsetX: -0.07)),
                samples(near: feature(yaw: -0.20, pitch: 0.04, pupilOffsetX: -0.05))
            ]
        )

        XCTAssertEqual(calibration.recommendedScreenLayoutMode, .horizontal)
    }

    func testCalibrationRecommendsVerticalLayoutForStackedAwaySamples() throws {
        let play = feature(yaw: 0.20, pitch: 0.02, pupilOffsetX: 0.05, pupilOffsetY: 0.00)
        let calibration = try FocusCalibration.make(
            playSamples: samples(near: play),
            pauseGroups: [
                samples(near: feature(yaw: 0.20, pitch: 0.12, pupilOffsetX: 0.05, pupilOffsetY: 0.07)),
                samples(near: feature(yaw: 0.20, pitch: 0.10, pupilOffsetX: 0.05, pupilOffsetY: 0.06)),
                samples(near: feature(yaw: 0.20, pitch: 0.14, pupilOffsetX: 0.05, pupilOffsetY: 0.08))
            ]
        )

        XCTAssertEqual(calibration.recommendedScreenLayoutMode, .vertical)
    }

    func testCalibrationRecommendsMixedLayoutForDiagonalAwaySamples() throws {
        let play = feature(yaw: 0.20, pitch: 0.02, pupilOffsetX: 0.05, pupilOffsetY: 0.00)
        let calibration = try FocusCalibration.make(
            playSamples: samples(near: play),
            pauseGroups: [
                samples(near: feature(yaw: -0.02, pitch: 0.12, pupilOffsetX: -0.01, pupilOffsetY: 0.05)),
                samples(near: feature(yaw: -0.04, pitch: 0.10, pupilOffsetX: -0.02, pupilOffsetY: 0.05)),
                samples(near: feature(yaw: 0.00, pitch: 0.11, pupilOffsetX: -0.01, pupilOffsetY: 0.04))
            ]
        )

        XCTAssertEqual(calibration.recommendedScreenLayoutMode, .mixed)
    }

    func testBalancedSensitivityActivatesAfterStablePlayFrames() throws {
        let playFeature = feature(yaw: 0.34, pupilOffsetX: 0.08)
        let pauseFeature = feature(yaw: -0.32, pupilOffsetX: -0.07)
        let calibration = try calibration(play: playFeature, pause: pauseFeature)
        var engine = FocusDecisionEngine()

        XCTAssertEqual(engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced).status, .unknown)
        XCTAssertEqual(engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced).status, .unknown)
        XCTAssertEqual(engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced).status, .active)
    }

    func testBalancedSensitivityDeactivatesAfterStablePauseFrames() throws {
        let playFeature = feature(yaw: 0.34, pupilOffsetX: 0.08)
        let pauseFeature = feature(yaw: -0.32, pupilOffsetX: -0.07)
        let calibration = try calibration(play: playFeature, pause: pauseFeature)
        var engine = FocusDecisionEngine()

        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced)
        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced)
        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced)

        XCTAssertEqual(engine.update(feature: .success(pauseFeature), calibration: calibration, sensitivity: .balanced).status, .active)
        XCTAssertEqual(engine.update(feature: .success(pauseFeature), calibration: calibration, sensitivity: .balanced).status, .inactive)
    }

    func testDistanceFilterPreventsFarFaceActivation() throws {
        let playFeature = feature(yaw: 0.34, pupilOffsetX: 0.08)
        let pauseFeature = feature(yaw: -0.32, pupilOffsetX: -0.07)
        let farPlay = feature(yaw: 0.34, faceHeight: 0.08, eyeDistance: 0.032, pupilOffsetX: 0.08)
        let calibration = try calibration(play: playFeature, pause: pauseFeature)
        var engine = FocusDecisionEngine()

        XCTAssertEqual(engine.update(feature: .success(farPlay), calibration: calibration, sensitivity: .balanced).status, .unknown)
        XCTAssertEqual(engine.update(feature: .success(farPlay), calibration: calibration, sensitivity: .balanced).status, .invalidDistance)
    }

    func testHorizontalLayoutKeepsVerticalWiggleActive() throws {
        let playFeature = feature(yaw: 0.34, pitch: 0.04, pupilOffsetX: 0.08, pupilOffsetY: 0.01)
        let pauseFeature = feature(yaw: -0.32, pitch: 0.04, pupilOffsetX: -0.07, pupilOffsetY: 0.01)
        let verticalWiggle = feature(yaw: 0.34, pitch: 0.14, pupilOffsetX: 0.08, pupilOffsetY: 0.08)
        let calibration = try calibration(play: playFeature, pause: pauseFeature)
        var engine = FocusDecisionEngine()

        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .horizontal)
        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .horizontal)
        XCTAssertEqual(engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .horizontal).status, .active)

        XCTAssertEqual(engine.update(feature: .success(verticalWiggle), calibration: calibration, sensitivity: .balanced, layoutMode: .horizontal).status, .active)
        XCTAssertEqual(engine.update(feature: .success(verticalWiggle), calibration: calibration, sensitivity: .balanced, layoutMode: .horizontal).status, .active)
    }

    func testVerticalLayoutKeepsHorizontalWiggleActive() throws {
        let playFeature = feature(yaw: 0.12, pitch: 0.04, pupilOffsetX: 0.02, pupilOffsetY: 0.01)
        let pauseFeature = feature(yaw: 0.12, pitch: 0.16, pupilOffsetX: 0.02, pupilOffsetY: 0.09)
        let horizontalWiggle = feature(yaw: -0.04, pitch: 0.04, pupilOffsetX: -0.06, pupilOffsetY: 0.01)
        let calibration = try FocusCalibration.make(
            playSamples: samples(near: playFeature),
            pauseGroups: [
                samples(near: pauseFeature),
                samples(near: feature(yaw: 0.12, pitch: 0.18, pupilOffsetX: 0.02, pupilOffsetY: 0.10)),
                samples(near: feature(yaw: 0.12, pitch: 0.14, pupilOffsetX: 0.02, pupilOffsetY: 0.08))
            ]
        )
        var engine = FocusDecisionEngine()

        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .vertical)
        _ = engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .vertical)
        XCTAssertEqual(engine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .vertical).status, .active)

        XCTAssertEqual(engine.update(feature: .success(horizontalWiggle), calibration: calibration, sensitivity: .balanced, layoutMode: .vertical).status, .active)
        XCTAssertEqual(engine.update(feature: .success(horizontalWiggle), calibration: calibration, sensitivity: .balanced, layoutMode: .vertical).status, .active)
    }

    func testMixedLayoutRequiresClearerMovementThanLegacyDistance() throws {
        let playFeature = feature(yaw: 0.34, pupilOffsetX: 0.08)
        let pauseFeature = feature(yaw: -0.32, pupilOffsetX: -0.07)
        let halfwayFeature = feature(yaw: 0.01, pupilOffsetX: 0.005)
        let calibration = try calibration(play: playFeature, pause: pauseFeature)
        var legacyEngine = FocusDecisionEngine()
        var mixedEngine = FocusDecisionEngine()

        for _ in 0..<3 {
            _ = legacyEngine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced)
            _ = mixedEngine.update(feature: .success(playFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .mixed)
        }

        _ = legacyEngine.update(feature: .success(halfwayFeature), calibration: calibration, sensitivity: .balanced)
        XCTAssertEqual(legacyEngine.update(feature: .success(halfwayFeature), calibration: calibration, sensitivity: .balanced).status, .inactive)

        _ = mixedEngine.update(feature: .success(halfwayFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .mixed)
        XCTAssertEqual(mixedEngine.update(feature: .success(halfwayFeature), calibration: calibration, sensitivity: .balanced, layoutMode: .mixed).status, .active)
    }

    func testMissingFaceEventuallyBecomesInactive() throws {
        let playFeature = feature(yaw: 0.34, pupilOffsetX: 0.08)
        let pauseFeature = feature(yaw: -0.32, pupilOffsetX: -0.07)
        let calibration = try calibration(play: playFeature, pause: pauseFeature)
        var engine = FocusDecisionEngine()

        for _ in 0..<3 {
            XCTAssertEqual(engine.update(feature: .failure(.noFace), calibration: calibration, sensitivity: .balanced).status, .unknown)
        }
        XCTAssertEqual(engine.update(feature: .failure(.noFace), calibration: calibration, sensitivity: .balanced).status, .inactive)
    }

    private func calibration(play: FaceFeatures, pause: FaceFeatures) throws -> FocusCalibration {
        try FocusCalibration.make(
            playSamples: samples(near: play),
            pauseGroups: [
                samples(near: pause),
                samples(near: feature(yaw: pause.yaw - 0.04, pupilOffsetX: pause.pupilOffsetX)),
                samples(near: feature(yaw: pause.yaw, pitch: pause.pitch + 0.05, pupilOffsetX: pause.pupilOffsetX))
            ]
        )
    }

    private func samples(near base: FaceFeatures) -> [FaceFeatures] {
        (0..<6).map { index in
            feature(
                yaw: base.yaw + (Double(index) * 0.001),
                pitch: base.pitch,
                roll: base.roll,
                faceCenterX: base.faceCenterX,
                faceCenterY: base.faceCenterY,
                faceHeight: base.faceHeight,
                eyeDistance: base.eyeDistance,
                leftEyeOpenness: base.leftEyeOpenness,
                rightEyeOpenness: base.rightEyeOpenness,
                pupilOffsetX: base.pupilOffsetX,
                pupilOffsetY: base.pupilOffsetY
            )
        }
    }

    private func feature(
        yaw: Double,
        pitch: Double = 0.04,
        roll: Double = 0.01,
        faceCenterX: Double = 0.52,
        faceCenterY: Double = 0.54,
        faceHeight: Double = 0.18,
        eyeDistance: Double = 0.072,
        leftEyeOpenness: Double = 0.29,
        rightEyeOpenness: Double = 0.30,
        pupilOffsetX: Double,
        pupilOffsetY: Double = 0.01
    ) -> FaceFeatures {
        FaceFeatures(
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            faceCenterX: faceCenterX,
            faceCenterY: faceCenterY,
            faceHeight: faceHeight,
            eyeDistance: eyeDistance,
            leftEyeOpenness: leftEyeOpenness,
            rightEyeOpenness: rightEyeOpenness,
            pupilOffsetX: pupilOffsetX,
            pupilOffsetY: pupilOffsetY
        )
    }
}
