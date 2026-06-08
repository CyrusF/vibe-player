import AVFoundation
import Combine
import Foundation

@MainActor
public final class AppStore: ObservableObject {
    @Published public private(set) var permissions: PermissionSnapshot
    @Published public private(set) var displays: [DisplayInfo]
    @Published public var selectedDisplayID: UInt32? {
        didSet {
            preferences.selectedDisplayID = selectedDisplayID
        }
    }
    @Published public private(set) var selectedTarget: PlayerTarget?
    @Published public private(set) var calibration: FocusCalibration?
    @Published public var sensitivity: Sensitivity {
        didSet {
            preferences.sensitivity = sensitivity
            decisionEngine.reset()
        }
    }
    @Published public var mediaKeyFallbackEnabled: Bool {
        didSet {
            preferences.mediaFallbackEnabled = mediaKeyFallbackEnabled
        }
    }
    @Published public var language: AppLanguage = .english {
        didSet {
            preferences.appLanguage = language
            relocalizeCurrentMessages(from: oldValue)
        }
    }
    @Published public private(set) var isDetectionEnabled = false
    @Published public private(set) var status: DetectionStatus = .unknown
    @Published public private(set) var statusDetail = "Ready."
    @Published public private(set) var lastScore: Double?
    @Published public private(set) var calibrationDraft = CalibrationDraft()
    @Published public private(set) var activeCalibrationClip: CalibrationClip?
    @Published public private(set) var calibrationProgress: Double = 0
    @Published public private(set) var calibrationMessage = "Record one play clip and three away clips."
    @Published public private(set) var hasCompletedOnboarding: Bool
    @Published public private(set) var watchHistory: [VideoWatchEvent]
    @Published public private(set) var activeWatchSession: ActiveVideoWatchSession?

    public let cameraMonitor: CameraFocusMonitor

    private let preferences: PreferencesStore
    private let permissionService: PermissionService
    private let displayService: DisplayService
    private let overlayService: OverlayService
    private let playerController: PlayerControlling
    private let mediaKeyService: MediaKeyControlling
    private var decisionEngine = FocusDecisionEngine()
    private var previousStatus: DetectionStatus = .unknown
    private var lastAutoPausedTargetID: UUID?
    private var pendingResumeTargetID: UUID?
    private var captureSamples: [FaceFeatures] = []
    private var captureTask: Task<Void, Never>?
    private var resumeRetryTask: Task<Void, Never>?
    private let now: @MainActor () -> Date
    private let watchHistoryLimit = 600

    public static func live() -> AppStore {
        AppStore()
    }

    public init(
        preferences: PreferencesStore = PreferencesStore(),
        permissionService: PermissionService = PermissionService(),
        displayService: DisplayService = DisplayService(),
        overlayService: OverlayService? = nil,
        cameraMonitor: CameraFocusMonitor = CameraFocusMonitor(),
        playerController: PlayerControlling = BrowserVideoController(),
        mediaKeyService: MediaKeyControlling = MediaKeyService(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.preferences = preferences
        self.permissionService = permissionService
        self.displayService = displayService
        self.overlayService = overlayService ?? OverlayService()
        self.cameraMonitor = cameraMonitor
        self.playerController = playerController
        self.mediaKeyService = mediaKeyService
        self.now = now

        self.permissions = permissionService.snapshot()
        self.displays = displayService.displays()
        self.selectedDisplayID = preferences.selectedDisplayID ?? displayService.recommendedDisplayID()
        self.selectedTarget = preferences.target
        self.calibration = preferences.calibration
        self.sensitivity = preferences.sensitivity
        self.mediaKeyFallbackEnabled = preferences.mediaFallbackEnabled
        let appLanguage = preferences.appLanguage
        self.language = appLanguage
        self.statusDetail = appLanguage.text(.ready)
        self.calibrationMessage = appLanguage.text(.calibrationInstructions)
        self.hasCompletedOnboarding = preferences.completedOnboarding
        self.watchHistory = preferences.watchHistory

        cameraMonitor.onFeature = { [weak self] result in
            Task { @MainActor in
                self?.handleFeature(result)
            }
        }
    }

    deinit {
        captureTask?.cancel()
        resumeRetryTask?.cancel()
    }

    public func text(_ key: AppTextKey) -> String {
        language.text(key)
    }

    public func statusTitle(_ status: DetectionStatus) -> String {
        language.statusTitle(status)
    }

    public func sensitivityTitle(_ sensitivity: Sensitivity) -> String {
        language.sensitivityTitle(sensitivity)
    }

    public func calibrationClipTitle(_ clip: CalibrationClip) -> String {
        language.calibrationClipTitle(clip)
    }

    public func sampleCount(_ count: Int) -> String {
        language.sampleCount(count)
    }

    public func displayName(for display: DisplayInfo) -> String {
        language.displayName(for: display)
    }

    public var watchHistoryByDay: [VideoWatchDay] {
        dailyWatchHistory(forPastDays: 14)
    }

    public var totalWatchDurationToday: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        return watchHistory.reduce(0) { total, event in
            calendar.isDate(event.startedAt, inSameDayAs: today) ? total + event.duration : total
        } + activeWatchDurationForDay(today, calendar: calendar)
    }

    public var totalWatchDurationThisWeek: TimeInterval {
        let calendar = Calendar.current
        let currentDate = now()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: currentDate) else {
            return totalWatchDurationToday
        }
        return watchHistory.reduce(0) { total, event in
            event.startedAt >= interval.start && event.startedAt < interval.end ? total + event.duration : total
        } + (activeWatchSession.map { session in
            session.startedAt >= interval.start && session.startedAt < interval.end
                ? max(0, currentDate.timeIntervalSince(session.startedAt))
                : 0
        } ?? 0)
    }

    public func clearWatchHistory() {
        activeWatchSession = nil
        watchHistory = []
        preferences.watchHistory = []
    }

    public func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
    }

    public func refresh() {
        permissions = permissionService.snapshot()
        displays = displayService.displays()
        if selectedDisplayID == nil {
            selectedDisplayID = displayService.recommendedDisplayID()
        }
    }

    public func requestCameraAccess() {
        Task { [weak self] in
            guard let self else { return }
            _ = await permissionService.requestCameraAccess()
            await MainActor.run {
                self.refresh()
            }
        }
    }

    public func markOnboardingComplete() {
        hasCompletedOnboarding = true
        preferences.completedOnboarding = true
    }

    public func selectDisplay(_ display: DisplayInfo) {
        selectedDisplayID = display.id
        overlayService.showDisplayMarkers(displays: displays, selectedID: selectedDisplayID)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            overlayService.hideDisplayMarkers()
        }
    }

    public func showDisplayMarkers() {
        refresh()
        overlayService.showDisplayMarkers(displays: displays, selectedID: selectedDisplayID)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            overlayService.hideDisplayMarkers()
        }
    }

    public func previewGlow() {
        refresh()
        overlayService.flashGlow(on: displayService.screen(for: selectedDisplayID), style: .active)
    }

    public func captureTarget(in browser: BrowserKind) {
        switch playerController.captureActiveTarget(in: browser) {
        case .success(let target):
            selectedTarget = target
            preferences.target = target
            statusDetail = language.capturedTarget(browserName: browser.displayName, title: target.title)
        case .failure(let error):
            statusDetail = language.playerControlErrorDescription(error)
        }
    }

    public func startDetection() {
        refresh()
        guard permissions.camera == .authorized else {
            status = .unknown
            statusDetail = text(.cameraPermissionRequired)
            return
        }
        guard calibration != nil else {
            status = .unknown
            statusDetail = text(.calibrationRequiredBeforeDetection)
            return
        }
        isDetectionEnabled = true
        decisionEngine.reset()
        previousStatus = .unknown
        status = .unknown
        statusDetail = text(.detectionRunning)
        cameraMonitor.start()
    }

    public func stopDetection() {
        isDetectionEnabled = false
        cameraMonitor.stop()
        decisionEngine.reset()
        resumeRetryTask?.cancel()
        resumeRetryTask = nil
        pendingResumeTargetID = nil
        previousStatus = .unknown
        status = .unknown
        statusDetail = text(.detectionPaused)
        finishActiveWatchSession(at: now())
    }

    public func resetCalibration() {
        stopDetection()
        calibration = nil
        preferences.calibration = nil
        calibrationDraft = CalibrationDraft()
        calibrationMessage = text(.calibrationInstructions)
        lastAutoPausedTargetID = nil
        pendingResumeTargetID = nil
        resumeRetryTask?.cancel()
        resumeRetryTask = nil
    }

    public func beginCalibrationCapture(_ clip: CalibrationClip) {
        refresh()
        guard permissions.camera == .authorized else {
            calibrationMessage = text(.cameraPermissionRequiredBeforeCalibration)
            return
        }
        if case .away = clip, calibrationDraft.playSamples.count < FocusCalibration.minimumSamplesPerClip {
            calibrationMessage = text(.recordPlayBeforeAwayClips)
            return
        }

        captureTask?.cancel()
        captureSamples.removeAll()
        activeCalibrationClip = clip
        calibrationProgress = 0
        calibrationMessage = language.recordingClip(clip)
        cameraMonitor.start()

        captureTask = Task { [weak self] in
            guard let self else { return }
            let steps = 20
            for step in 1...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    self.calibrationProgress = Double(step) / Double(steps)
                }
            }
            await MainActor.run {
                self.finishCalibrationCapture()
            }
        }
    }

    private func finishCalibrationCapture() {
        guard let clip = activeCalibrationClip else { return }
        activeCalibrationClip = nil
        calibrationProgress = 0

        let samples = captureSamples
        captureSamples.removeAll()
        guard samples.count >= FocusCalibration.minimumSamplesPerClip else {
            calibrationMessage = language.clipInvalidNotEnoughSamples(clip)
            return
        }

        if case .away(let index) = clip,
           let play = FaceFeatures.centroid(calibrationDraft.playSamples),
           let pause = FaceFeatures.centroid(samples) {
            let distance = FaceFeatures.calibrationSeparationDistance(play, pause)
            guard distance >= FocusCalibration.minimumAwayDistance else {
                calibrationMessage = language.awayClipTooSimilar(index: index)
                return
            }
        }

        calibrationDraft.set(samples: samples, for: clip)
        calibrationMessage = language.clipRecorded(clip, sampleCount: samples.count)

        if calibrationDraft.canBuild {
            do {
                let built = try calibrationDraft.build()
                calibration = built
                preferences.calibration = built
                calibrationMessage = text(.calibrationComplete)
                cameraMonitor.stop()
            } catch {
                calibrationMessage = language.localizedErrorDescription(error)
            }
        }
    }

    private func handleFeature(_ result: Result<FaceFeatures, FaceDetectionError>) {
        if activeCalibrationClip != nil, case .success(let feature) = result {
            captureSamples.append(feature)
        }

        guard isDetectionEnabled else { return }
        let decision = decisionEngine.update(
            feature: result,
            calibration: calibration,
            sensitivity: sensitivity,
            language: language
        )
        status = decision.status
        statusDetail = decision.message
        lastScore = decision.score

        guard decision.status != previousStatus else { return }
        let oldStatus = previousStatus
        previousStatus = decision.status
        handleStatusTransition(from: oldStatus, to: decision.status)
    }

    private func handleStatusTransition(from oldStatus: DetectionStatus, to newStatus: DetectionStatus) {
        let screen = displayService.screen(for: selectedDisplayID)
        switch newStatus {
        case .active:
            overlayService.flashGlow(on: screen, style: .active)
            resumeIfNeeded()
        case .inactive:
            overlayService.flashGlow(on: screen, style: .inactive)
            pauseIfNeeded()
        case .invalidDistance:
            overlayService.flashGlow(on: screen, style: .invalid)
            if oldStatus == .active {
                pauseIfNeeded()
            }
        case .unknown:
            break
        }
    }

    private func pauseIfNeeded() {
        guard let target = selectedTarget else {
            statusDetail = text(.noBrowserVideoTargetSelected)
            return
        }
        let eventDate = now()
        resumeRetryTask?.cancel()
        resumeRetryTask = nil
        pendingResumeTargetID = nil
        switch playerController.control(.pause, target: target) {
        case .success(let result):
            if result.ok && result.changed {
                lastAutoPausedTargetID = target.id
                statusDetail = text(.pausedSelectedVideo)
                finishActiveWatchSession(at: eventDate)
            } else {
                lastAutoPausedTargetID = nil
                statusDetail = language.videoReason(result.reason) ?? text(.selectedVideoAlreadyPaused)
                if result.ok && result.isPaused == true {
                    finishActiveWatchSession(at: eventDate)
                }
            }
        case .failure(let error):
            if mediaKeyFallbackEnabled {
                mediaKeyService.sendPlayPause()
                lastAutoPausedTargetID = target.id
                statusDetail = language.sentMediaFallback(after: language.playerControlErrorDescription(error))
                finishActiveWatchSession(at: eventDate)
            } else {
                statusDetail = language.playerControlErrorDescription(error)
            }
        }
    }

    private func resumeIfNeeded() {
        guard let target = selectedTarget else {
            return
        }
        let eventDate = now()
        let isAppResume = lastAutoPausedTargetID == target.id
        pendingResumeTargetID = target.id
        resumeRetryTask?.cancel()
        resumeRetryTask = nil
        switch playerController.control(.play, target: target) {
        case .success(let result):
            if result.ok && result.isPaused == false {
                clearResumeState(for: target)
                statusDetail = isAppResume ? text(.resumedSelectedVideo) : text(.startedSelectedVideo)
                beginWatchSessionIfNeeded(target: target, at: eventDate)
            } else {
                statusDetail = language.videoReason(result.reason) ?? text(.resumeRequestedVerifyingPlayback)
                scheduleResumeVerification(target: target, attemptsRemaining: 2)
            }
        case .failure(let error):
            if mediaKeyFallbackEnabled {
                mediaKeyService.sendPlayPause()
                statusDetail = language.sentMediaFallback(after: language.playerControlErrorDescription(error))
                beginWatchSessionIfNeeded(target: target, at: eventDate)
                scheduleResumeVerification(target: target, attemptsRemaining: 0)
            } else {
                statusDetail = language.playerControlErrorDescription(error)
            }
        }
    }

    private func scheduleResumeVerification(target: PlayerTarget, attemptsRemaining: Int) {
        resumeRetryTask?.cancel()
        resumeRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run {
                self?.verifyResume(target: target, attemptsRemaining: attemptsRemaining)
            }
        }
    }

    private func verifyResume(target: PlayerTarget, attemptsRemaining: Int) {
        guard pendingResumeTargetID == target.id else { return }

        switch playerController.control(.status, target: target) {
        case .success(let result):
            if result.ok && result.isPaused == false {
                clearResumeState(for: target)
                statusDetail = text(.resumedSelectedVideo)
                beginWatchSessionIfNeeded(target: target, at: now())
                return
            }

            if attemptsRemaining > 0 {
                statusDetail = text(.retryingVideoResume)
                switch playerController.control(.play, target: target) {
                case .success(let retryResult):
                    if retryResult.ok && retryResult.isPaused == false {
                        clearResumeState(for: target)
                        statusDetail = text(.resumedSelectedVideo)
                        beginWatchSessionIfNeeded(target: target, at: now())
                    } else {
                        scheduleResumeVerification(target: target, attemptsRemaining: attemptsRemaining - 1)
                    }
                case .failure(let error):
                    statusDetail = language.playerControlErrorDescription(error)
                    scheduleResumeVerification(target: target, attemptsRemaining: attemptsRemaining - 1)
                }
                return
            }

            if mediaKeyFallbackEnabled {
                mediaKeyService.sendPlayPause()
                statusDetail = text(.sentMediaFallbackToResume)
                scheduleMediaKeyResumeConfirmation(target: target)
            } else {
                statusDetail = text(.resumeStillPausedEnableFallback)
            }

        case .failure(let error):
            if mediaKeyFallbackEnabled {
                mediaKeyService.sendPlayPause()
                statusDetail = language.sentMediaFallback(after: language.playerControlErrorDescription(error))
                scheduleMediaKeyResumeConfirmation(target: target)
            } else {
                statusDetail = language.playerControlErrorDescription(error)
            }
        }
    }

    private func scheduleMediaKeyResumeConfirmation(target: PlayerTarget) {
        resumeRetryTask?.cancel()
        resumeRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            await MainActor.run {
                guard let self, self.pendingResumeTargetID == target.id else { return }
                switch self.playerController.control(.status, target: target) {
                case .success(let result) where result.isPaused == false:
                    self.clearResumeState(for: target)
                    self.statusDetail = self.text(.resumedSelectedVideo)
                    self.beginWatchSessionIfNeeded(target: target, at: self.now())
                case .success:
                    self.statusDetail = self.text(.mediaKeyFallbackDidNotConfirm)
                case .failure(let error):
                    self.statusDetail = self.language.playerControlErrorDescription(error)
                }
            }
        }
    }

    private func relocalizeCurrentMessages(from oldLanguage: AppLanguage) {
        statusDetail = relocalized(
            statusDetail,
            from: oldLanguage,
            matching: [
                .ready,
                .cameraPermissionRequired,
                .calibrationRequiredBeforeDetection,
                .detectionRunning,
                .detectionPaused,
                .noBrowserVideoTargetSelected,
                .pausedSelectedVideo,
                .selectedVideoAlreadyPaused,
                .resumedSelectedVideo,
                .startedSelectedVideo,
                .resumeRequestedVerifyingPlayback,
                .retryingVideoResume,
                .sentMediaFallbackToResume,
                .resumeStillPausedEnableFallback,
                .mediaKeyFallbackDidNotConfirm
            ]
        )

        if let activeCalibrationClip,
           calibrationMessage == oldLanguage.recordingClip(activeCalibrationClip) {
            calibrationMessage = language.recordingClip(activeCalibrationClip)
        } else {
            calibrationMessage = relocalized(
                calibrationMessage,
                from: oldLanguage,
                matching: [
                    .calibrationInstructions,
                    .cameraPermissionRequiredBeforeCalibration,
                    .recordPlayBeforeAwayClips,
                    .calibrationComplete
                ]
            )
        }
    }

    private func relocalized(
        _ value: String,
        from oldLanguage: AppLanguage,
        matching keys: [AppTextKey]
    ) -> String {
        guard let key = keys.first(where: { oldLanguage.text($0) == value }) else {
            return value
        }
        return language.text(key)
    }

    private func clearResumeState(for target: PlayerTarget) {
        pendingResumeTargetID = nil
        resumeRetryTask?.cancel()
        resumeRetryTask = nil
        if lastAutoPausedTargetID == target.id {
            lastAutoPausedTargetID = nil
        }
    }

    private func beginWatchSessionIfNeeded(target: PlayerTarget, at date: Date) {
        if let activeWatchSession,
           activeWatchSession.url == target.url,
           activeWatchSession.title == target.title {
            return
        }

        finishActiveWatchSession(at: date)
        activeWatchSession = ActiveVideoWatchSession(
            startedAt: date,
            title: target.title,
            url: target.url,
            browserName: target.browser.displayName
        )
    }

    private func finishActiveWatchSession(at date: Date) {
        guard let session = activeWatchSession else { return }
        activeWatchSession = nil

        guard date.timeIntervalSince(session.startedAt) >= 5 else { return }
        watchHistory.append(VideoWatchEvent(
            startedAt: session.startedAt,
            endedAt: date,
            title: session.title,
            url: session.url,
            browserName: session.browserName
        ))
        if watchHistory.count > watchHistoryLimit {
            watchHistory.removeFirst(watchHistory.count - watchHistoryLimit)
        }
        preferences.watchHistory = watchHistory
    }

    private func dailyWatchHistory(forPastDays dayCount: Int) -> [VideoWatchDay] {
        let calendar = Calendar.current
        let currentDate = now()
        let today = calendar.startOfDay(for: currentDate)
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        var buckets: [Date: TimeInterval] = [:]

        for offset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: start) {
                buckets[date] = 0
            }
        }

        for event in watchHistory {
            let day = calendar.startOfDay(for: event.startedAt)
            guard day >= start && day <= today else { continue }
            buckets[day, default: 0] += event.duration
        }

        if let activeWatchSession {
            let day = calendar.startOfDay(for: activeWatchSession.startedAt)
            if day >= start && day <= today {
                buckets[day, default: 0] += max(0, currentDate.timeIntervalSince(activeWatchSession.startedAt))
            }
        }

        return (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return VideoWatchDay(date: date, duration: buckets[date, default: 0])
        }
    }

    private func activeWatchDurationForDay(_ day: Date, calendar: Calendar) -> TimeInterval {
        guard let activeWatchSession,
              calendar.isDate(activeWatchSession.startedAt, inSameDayAs: day) else {
            return 0
        }
        return max(0, now().timeIntervalSince(activeWatchSession.startedAt))
    }
}
