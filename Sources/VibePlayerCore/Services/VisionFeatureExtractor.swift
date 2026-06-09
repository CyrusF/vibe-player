import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Vision

public final class VisionFeatureExtractor {
    private let minimumFaceHeight: Double = 0.045
    private static let primaryFaceDominanceRatio: CGFloat = 1.35

    public init() {}

    public func extract(from sampleBuffer: CMSampleBuffer) -> Result<FaceFeatures, FaceDetectionError> {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return .failure(.extractionFailed(error.localizedDescription))
        }

        guard let faces = request.results else {
            return .failure(.noFace)
        }
        guard !faces.isEmpty else {
            return .failure(.noFace)
        }
        guard let primaryIndex = Self.primaryFaceIndex(in: faces.map(\.boundingBox)) else {
            return .failure(.multipleFaces)
        }
        let face = faces[primaryIndex]
        guard face.boundingBox.height >= minimumFaceHeight else {
            return .failure(.faceTooSmall)
        }
        guard let landmarks = face.landmarks else {
            return .failure(.missingLandmarks)
        }
        guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye,
              leftEye.pointCount >= 4, rightEye.pointCount >= 4 else {
            return .failure(.missingEyes)
        }

        let leftEyePoints = normalizedPoints(for: leftEye, in: face.boundingBox)
        let rightEyePoints = normalizedPoints(for: rightEye, in: face.boundingBox)
        let leftCenter = center(of: leftEyePoints)
        let rightCenter = center(of: rightEyePoints)
        let eyeDistance = distance(leftCenter, rightCenter)

        guard eyeDistance > 0.001 else {
            return .failure(.missingEyes)
        }

        let leftOpenness = openness(of: leftEyePoints)
        let rightOpenness = openness(of: rightEyePoints)
        let pupilOffset = pupilOffset(
            landmarks: landmarks,
            faceBox: face.boundingBox,
            leftEyeCenter: leftCenter,
            rightEyeCenter: rightCenter,
            eyeDistance: eyeDistance
        )

        let feature = FaceFeatures(
            yaw: face.yaw?.doubleValue ?? 0,
            pitch: face.pitch?.doubleValue ?? 0,
            roll: face.roll?.doubleValue ?? 0,
            faceCenterX: face.boundingBox.midX,
            faceCenterY: face.boundingBox.midY,
            faceHeight: face.boundingBox.height,
            eyeDistance: eyeDistance,
            leftEyeOpenness: leftOpenness,
            rightEyeOpenness: rightOpenness,
            pupilOffsetX: pupilOffset.x,
            pupilOffsetY: pupilOffset.y
        )

        return .success(feature)
    }

    private func normalizedPoints(for region: VNFaceLandmarkRegion2D, in faceBox: CGRect) -> [CGPoint] {
        region.normalizedPoints.map { point in
            CGPoint(
                x: faceBox.minX + (CGFloat(point.x) * faceBox.width),
                y: faceBox.minY + (CGFloat(point.y) * faceBox.height)
            )
        }
    }

    private func center(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let count = CGFloat(points.count)
        let x = points.reduce(CGFloat.zero) { $0 + $1.x } / count
        let y = points.reduce(CGFloat.zero) { $0 + $1.y } / count
        return CGPoint(x: x, y: y)
    }

    private func openness(of points: [CGPoint]) -> Double {
        guard let minX = points.map(\.x).min(),
              let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max() else {
            return 0
        }
        let width = max(0.001, maxX - minX)
        return Double((maxY - minY) / width)
    }

    private func pupilOffset(
        landmarks: VNFaceLandmarks2D,
        faceBox: CGRect,
        leftEyeCenter: CGPoint,
        rightEyeCenter: CGPoint,
        eyeDistance: Double
    ) -> CGPoint {
        guard let leftPupil = landmarks.leftPupil, let rightPupil = landmarks.rightPupil,
              leftPupil.pointCount > 0, rightPupil.pointCount > 0 else {
            return .zero
        }
        let leftPupilCenter = center(of: normalizedPoints(for: leftPupil, in: faceBox))
        let rightPupilCenter = center(of: normalizedPoints(for: rightPupil, in: faceBox))
        let eyeMid = midpoint(leftEyeCenter, rightEyeCenter)
        let pupilMid = midpoint(leftPupilCenter, rightPupilCenter)
        let scale = CGFloat(max(0.001, eyeDistance))
        return CGPoint(
            x: (pupilMid.x - eyeMid.x) / scale,
            y: (pupilMid.y - eyeMid.y) / scale
        )
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return Double(sqrt((dx * dx) + (dy * dy)))
    }

    static func primaryFaceIndex(in boundingBoxes: [CGRect]) -> Int? {
        guard !boundingBoxes.isEmpty else { return nil }
        guard boundingBoxes.count > 1 else { return 0 }

        let ranked = boundingBoxes.enumerated()
            .map { index, box in
                (index: index, area: box.width * box.height)
            }
            .sorted { $0.area > $1.area }
        guard let primary = ranked.first, let secondary = ranked.dropFirst().first else {
            return ranked.first?.index
        }
        guard primary.area >= max(0.0001, secondary.area) * primaryFaceDominanceRatio else {
            return nil
        }
        return primary.index
    }
}
