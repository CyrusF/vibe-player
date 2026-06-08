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
