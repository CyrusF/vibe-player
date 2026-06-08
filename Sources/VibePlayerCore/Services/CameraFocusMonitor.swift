import AVFoundation
import Combine
import Foundation

public final class CameraFocusMonitor: NSObject, ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var latestFeature: FaceFeatures?

    public var frameInterval: TimeInterval = 0.20
    public var onFeature: ((Result<FaceFeatures, FaceDetectionError>) -> Void)?

    private let extractor: VisionFeatureExtractor
    private let sessionQueue = DispatchQueue(label: "dev.local.vibeplayer.camera.session")
    private let processingQueue = DispatchQueue(label: "dev.local.vibeplayer.camera.processing")
    private var session: AVCaptureSession?
    private var lastFrameTime: TimeInterval = 0
    private var isProcessingFrame = false

    public init(extractor: VisionFeatureExtractor = VisionFeatureExtractor()) {
        self.extractor = extractor
        super.init()
    }

    public func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session == nil {
                self.session = self.makeSession()
            }
            guard let session = self.session, !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                self.lastErrorMessage = nil
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self, let session = self.session, session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func makeSession() -> AVCaptureSession? {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
            ?? AVCaptureDevice.default(for: .video) else {
            publish(.failure(.extractionFailed("No camera device found.")))
            return nil
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                publish(.failure(.extractionFailed("Could not add camera input.")))
                return nil
            }
            session.addInput(input)
        } catch {
            publish(.failure(.extractionFailed(error.localizedDescription)))
            return nil
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        guard session.canAddOutput(output) else {
            publish(.failure(.extractionFailed("Could not add camera output.")))
            return nil
        }
        session.addOutput(output)
        return session
    }

    private func publish(_ result: Result<FaceFeatures, FaceDetectionError>) {
        DispatchQueue.main.async { [weak self] in
            switch result {
            case .success(let feature):
                self?.latestFeature = feature
                self?.lastErrorMessage = nil
            case .failure(let error):
                self?.lastErrorMessage = error.localizedDescription
            }
            self?.onFeature?(result)
        }
    }
}

extension CameraFocusMonitor: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameTime >= frameInterval, !isProcessingFrame else { return }
        lastFrameTime = now
        isProcessingFrame = true
        let result = extractor.extract(from: sampleBuffer)
        isProcessingFrame = false
        publish(result)
    }
}
