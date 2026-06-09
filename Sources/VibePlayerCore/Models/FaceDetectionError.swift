import Foundation

public enum FaceDetectionError: LocalizedError, Equatable, Hashable, Sendable {
    case noFace
    case multipleFaces
    case missingLandmarks
    case missingEyes
    case faceTooSmall
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noFace:
            return "No face detected."
        case .multipleFaces:
            return "Multiple faces detected."
        case .missingLandmarks:
            return "Face landmarks were not detected."
        case .missingEyes:
            return "Eyes were not detected clearly."
        case .faceTooSmall:
            return "Face is too small or too far away."
        case .extractionFailed(let message):
            return message
        }
    }
}
