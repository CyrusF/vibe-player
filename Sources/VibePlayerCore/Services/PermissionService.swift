import AVFoundation
import Foundation

public struct PermissionSnapshot: Equatable, Sendable {
    public var camera: AVAuthorizationStatus

    public init(camera: AVAuthorizationStatus) {
        self.camera = camera
    }

    public var canRunDetection: Bool {
        camera == .authorized
    }
}

public final class PermissionService {
    public init() {}

    public func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            camera: AVCaptureDevice.authorizationStatus(for: .video)
        )
    }

    public func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

}
