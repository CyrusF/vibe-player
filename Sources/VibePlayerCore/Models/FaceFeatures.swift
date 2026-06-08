import Foundation

public struct FaceFeatures: Codable, Equatable, Sendable {
    public var yaw: Double
    public var pitch: Double
    public var roll: Double
    public var faceCenterX: Double
    public var faceCenterY: Double
    public var faceHeight: Double
    public var eyeDistance: Double
    public var leftEyeOpenness: Double
    public var rightEyeOpenness: Double
    public var pupilOffsetX: Double
    public var pupilOffsetY: Double

    public init(
        yaw: Double,
        pitch: Double,
        roll: Double,
        faceCenterX: Double,
        faceCenterY: Double,
        faceHeight: Double,
        eyeDistance: Double,
        leftEyeOpenness: Double,
        rightEyeOpenness: Double,
        pupilOffsetX: Double,
        pupilOffsetY: Double
    ) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.faceCenterX = faceCenterX
        self.faceCenterY = faceCenterY
        self.faceHeight = faceHeight
        self.eyeDistance = eyeDistance
        self.leftEyeOpenness = leftEyeOpenness
        self.rightEyeOpenness = rightEyeOpenness
        self.pupilOffsetX = pupilOffsetX
        self.pupilOffsetY = pupilOffsetY
    }

    public var distanceProxy: Double {
        max(0.001, (faceHeight * 0.72) + (eyeDistance * 0.28))
    }

    var vector: [Double] {
        [
            yaw * 1.55,
            pitch * 1.65,
            roll * 0.80,
            (faceCenterX - 0.5) * 1.25,
            (faceCenterY - 0.5) * 0.75,
            faceHeight * 0.90,
            eyeDistance * 1.15,
            leftEyeOpenness * 0.70,
            rightEyeOpenness * 0.70,
            pupilOffsetX * 1.50,
            pupilOffsetY * 1.80
        ]
    }

    var calibrationVector: [Double] {
        [
            yaw * 1.45,
            pitch * 2.10,
            roll * 0.65,
            (faceCenterX - 0.5) * 1.05,
            (faceCenterY - 0.5) * 1.05,
            faceHeight * 0.45,
            eyeDistance * 0.55,
            leftEyeOpenness * 0.55,
            rightEyeOpenness * 0.55,
            pupilOffsetX * 1.75,
            pupilOffsetY * 2.40
        ]
    }

    static func centroid(_ values: [FaceFeatures]) -> FaceFeatures? {
        guard !values.isEmpty else { return nil }
        let count = Double(values.count)
        return FaceFeatures(
            yaw: values.reduce(0) { $0 + $1.yaw } / count,
            pitch: values.reduce(0) { $0 + $1.pitch } / count,
            roll: values.reduce(0) { $0 + $1.roll } / count,
            faceCenterX: values.reduce(0) { $0 + $1.faceCenterX } / count,
            faceCenterY: values.reduce(0) { $0 + $1.faceCenterY } / count,
            faceHeight: values.reduce(0) { $0 + $1.faceHeight } / count,
            eyeDistance: values.reduce(0) { $0 + $1.eyeDistance } / count,
            leftEyeOpenness: values.reduce(0) { $0 + $1.leftEyeOpenness } / count,
            rightEyeOpenness: values.reduce(0) { $0 + $1.rightEyeOpenness } / count,
            pupilOffsetX: values.reduce(0) { $0 + $1.pupilOffsetX } / count,
            pupilOffsetY: values.reduce(0) { $0 + $1.pupilOffsetY } / count
        )
    }

    static func distance(_ lhs: FaceFeatures, _ rhs: FaceFeatures) -> Double {
        let a = lhs.vector
        let b = rhs.vector
        return euclideanDistance(a, b)
    }

    static func calibrationSeparationDistance(_ lhs: FaceFeatures, _ rhs: FaceFeatures) -> Double {
        euclideanDistance(lhs.calibrationVector, rhs.calibrationVector)
    }

    private static func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        let sum = zip(a, b).reduce(0.0) { partial, pair in
            let delta = pair.0 - pair.1
            return partial + (delta * delta)
        }
        return sqrt(sum)
    }
}
