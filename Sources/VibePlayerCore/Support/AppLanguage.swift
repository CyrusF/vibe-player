import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"

    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }

    public static func defaultLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let preferred = preferredLanguages.first else {
            return .english
        }
        return isChineseIdentifier(preferred) ? .chinese : .english
    }

    private static func isChineseIdentifier(_ identifier: String) -> Bool {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        return normalized == "zh" || normalized.hasPrefix("zh-")
    }
}

public enum AppTextKey: Sendable {
    case openVibePlayer
    case pauseDetection
    case startDetection
    case previewGlow
    case showDisplayMarkers
    case mediaKeyFallback
    case quit
    case language
    case start
    case pause
    case permissions
    case camera
    case request
    case openSettings
    case systemMediaKeyFallback
    case mediaFallbackEnabledDetail
    case mediaFallbackOptionalDetail
    case enabled
    case enable
    case browserAutomation
    case browserAutomationDetail
    case captureTarget
    case playbackDisplay
    case showMarkers
    case calibration
    case calibrationSaved
    case resetCalibration
    case recording
    case playerTarget
    case detectionSettings
    case sensitivity
    case useSystemPlayPauseFallback
    case fallbackNote
    case noBrowserVideoTargetSelected
    case allowed
    case notRequested
    case deniedInSystemSettings
    case restrictedBySystemPolicy
    case unknown
    case builtInDisplay
    case display
    case ready
    case calibrationInstructions
    case cameraPermissionRequired
    case calibrationRequiredBeforeDetection
    case detectionRunning
    case detectionPaused
    case cameraPermissionRequiredBeforeCalibration
    case recordPlayBeforeAwayClips
    case calibrationComplete
    case pausedSelectedVideo
    case selectedVideoAlreadyPaused
    case resumedSelectedVideo
    case startedSelectedVideo
    case resumeRequestedVerifyingPlayback
    case retryingVideoResume
    case sentMediaFallbackToResume
    case resumeStillPausedEnableFallback
    case mediaKeyFallbackDidNotConfirm
    case calibrationRequiredShort
}

public extension AppLanguage {
    func text(_ key: AppTextKey) -> String {
        switch self {
        case .english:
            return englishText(key)
        case .chinese:
            return chineseText(key)
        }
    }

    func statusTitle(_ status: DetectionStatus) -> String {
        switch (self, status) {
        case (.english, .active):
            return "Looking at playback screen"
        case (.english, .inactive):
            return "Away from playback screen"
        case (.english, .unknown):
            return "Waiting for face signal"
        case (.english, .invalidDistance):
            return "Face distance out of range"
        case (.chinese, .active):
            return "正在看播放屏幕"
        case (.chinese, .inactive):
            return "已离开播放屏幕"
        case (.chinese, .unknown):
            return "等待人脸信号"
        case (.chinese, .invalidDistance):
            return "人脸距离超出范围"
        }
    }

    func sensitivityTitle(_ sensitivity: Sensitivity) -> String {
        switch (self, sensitivity) {
        case (.english, .conservative):
            return "Conservative"
        case (.english, .balanced):
            return "Balanced"
        case (.english, .fast):
            return "Fast"
        case (.chinese, .conservative):
            return "稳健"
        case (.chinese, .balanced):
            return "均衡"
        case (.chinese, .fast):
            return "快速"
        }
    }

    func calibrationClipTitle(_ clip: CalibrationClip) -> String {
        switch clip {
        case .play:
            return self == .english ? "Play" : "播放"
        case .away(let index):
            return self == .english ? "Away \(index)" : "离开 \(index)"
        }
    }

    func sampleCount(_ count: Int) -> String {
        switch self {
        case .english:
            return "\(count) samples"
        case .chinese:
            return "\(count) 个样本"
        }
    }

    func displayName(for display: DisplayInfo) -> String {
        if display.isBuiltIn {
            return text(.builtInDisplay)
        }
        return "\(text(.display)) \(display.index)"
    }

    func capturedTarget(browserName: String, title: String) -> String {
        switch self {
        case .english:
            return "Captured \(browserName): \(title)"
        case .chinese:
            return "已捕获 \(browserName)：\(title)"
        }
    }

    func recordingClip(_ clip: CalibrationClip) -> String {
        switch self {
        case .english:
            return "Recording \(calibrationClipTitle(clip))."
        case .chinese:
            return "正在录制\(calibrationClipTitle(clip))。"
        }
    }

    func clipInvalidNotEnoughSamples(_ clip: CalibrationClip) -> String {
        switch self {
        case .english:
            return "\(calibrationClipTitle(clip)) invalid: not enough clear face samples."
        case .chinese:
            return "\(calibrationClipTitle(clip))无效：清晰人脸样本不足。"
        }
    }

    func awayClipTooSimilar(index: Int) -> String {
        switch self {
        case .english:
            return "Away \(index) invalid: too similar to play."
        case .chinese:
            return "离开 \(index) 无效：与播放样本太相似。"
        }
    }

    func clipRecorded(_ clip: CalibrationClip, sampleCount: Int) -> String {
        switch self {
        case .english:
            return "\(calibrationClipTitle(clip)) recorded with \(sampleCount) samples."
        case .chinese:
            return "\(calibrationClipTitle(clip))已录制 \(sampleCount) 个样本。"
        }
    }

    func sentMediaFallback(after errorDescription: String) -> String {
        switch self {
        case .english:
            return "Sent system Play/Pause fallback after: \(errorDescription)"
        case .chinese:
            return "已在失败后发送系统播放/暂停备用按键：\(errorDescription)"
        }
    }

    func distanceRatioOutOfRange(_ ratio: Double) -> String {
        let value = String(format: "%.2f", ratio)
        switch self {
        case .english:
            return "Distance ratio \(value) is outside calibration range."
        case .chinese:
            return "距离比例 \(value) 超出校准范围。"
        }
    }

    func focusScore(_ score: Double) -> String {
        let value = String(format: "%.2f", score)
        switch self {
        case .english:
            return "Focus score \(value)."
        case .chinese:
            return "专注分数 \(value)。"
        }
    }

    func faceDetectionErrorDescription(_ error: FaceDetectionError) -> String {
        switch (self, error) {
        case (.english, _):
            return error.localizedDescription
        case (.chinese, .noFace):
            return "未检测到人脸。"
        case (.chinese, .multipleFaces):
            return "检测到多张人脸。"
        case (.chinese, .missingLandmarks):
            return "未检测到人脸关键点。"
        case (.chinese, .missingEyes):
            return "眼睛检测不够清晰。"
        case (.chinese, .faceTooSmall):
            return "人脸太小或距离太远。"
        case (.chinese, .extractionFailed(let message)):
            return translatedExtractionFailure(message)
        }
    }

    func calibrationErrorDescription(_ error: CalibrationError) -> String {
        switch (self, error) {
        case (.english, _):
            return error.localizedDescription
        case (.chinese, .notEnoughSamples(let name)):
            if name == "Play calibration" {
                return "播放校准需要更多有效人脸样本。"
            }
            if name.hasPrefix("Away calibration ") {
                let index = name.replacingOccurrences(of: "Away calibration ", with: "")
                return "离开校准 \(index) 需要更多有效人脸样本。"
            }
            return "\(name) 需要更多有效人脸样本。"
        case (.chinese, .awayTooClose(let index, let distance)):
            return "离开样本 \(index) 与播放样本太接近（\(String(format: "%.2f", distance))）。"
        }
    }

    func playerControlErrorDescription(_ error: PlayerControlError) -> String {
        switch (self, error) {
        case (.english, _):
            return error.localizedDescription
        case (.chinese, .browserNotRunning(let name)):
            return "\(name) 未运行。"
        case (.chinese, .noTarget(let message)):
            return translatedBrowserMessage(message)
        case (.chinese, .scriptFailed(let message)):
            return "浏览器控制脚本执行失败：\(translatedBrowserMessage(message))"
        case (.chinese, .badResponse(let message)):
            return "浏览器返回了异常响应：\(message)"
        }
    }

    func videoReason(_ reason: String?) -> String? {
        guard let reason else { return nil }
        switch (self, reason) {
        case (.english, "no-visible-video"):
            return "No visible video found."
        case (.english, "paused"):
            return "Paused selected video."
        case (.english, "already-paused"):
            return "Selected video was already paused."
        case (.english, "playing"):
            return "Selected video is playing."
        case (.english, "already-playing"):
            return "Selected video was already playing."
        case (.english, "play-requested-still-paused"):
            return "Resume requested; verifying playback."
        case (.english, "unknown-action"):
            return "Unknown video control action."
        case (.chinese, "no-visible-video"):
            return "未找到可见视频。"
        case (.chinese, "paused"):
            return "已暂停所选视频。"
        case (.chinese, "already-paused"):
            return "所选视频已经暂停。"
        case (.chinese, "playing"):
            return "所选视频正在播放。"
        case (.chinese, "already-playing"):
            return "所选视频已经在播放。"
        case (.chinese, "play-requested-still-paused"):
            return "已请求恢复播放；正在确认播放状态。"
        case (.chinese, "unknown-action"):
            return "未知的视频控制操作。"
        default:
            return reason
        }
    }

    func localizedErrorDescription(_ error: Error) -> String {
        if let faceError = error as? FaceDetectionError {
            return faceDetectionErrorDescription(faceError)
        }
        if let calibrationError = error as? CalibrationError {
            return calibrationErrorDescription(calibrationError)
        }
        if let playerError = error as? PlayerControlError {
            return playerControlErrorDescription(playerError)
        }
        return error.localizedDescription
    }

    private func englishText(_ key: AppTextKey) -> String {
        switch key {
        case .openVibePlayer:
            return "Open Vibe Player"
        case .pauseDetection:
            return "Pause Detection"
        case .startDetection:
            return "Start Detection"
        case .previewGlow:
            return "Preview Glow"
        case .showDisplayMarkers:
            return "Show Display Markers"
        case .mediaKeyFallback:
            return "Media Key Fallback"
        case .quit:
            return "Quit"
        case .language:
            return "Language"
        case .start:
            return "Start"
        case .pause:
            return "Pause"
        case .permissions:
            return "Permissions"
        case .camera:
            return "Camera"
        case .request:
            return "Request"
        case .openSettings:
            return "Open Settings"
        case .systemMediaKeyFallback:
            return "System Media Key Fallback"
        case .mediaFallbackEnabledDetail:
            return "Enabled by default; used only if browser video control fails"
        case .mediaFallbackOptionalDetail:
            return "Optional global Play/Pause fallback"
        case .enabled:
            return "Enabled"
        case .enable:
            return "Enable"
        case .browserAutomation:
            return "Browser Automation"
        case .browserAutomationDetail:
            return "macOS asks the first time Vibe Player controls Safari or Chrome"
        case .captureTarget:
            return "Capture Target"
        case .playbackDisplay:
            return "Playback Display"
        case .showMarkers:
            return "Show Markers"
        case .calibration:
            return "Calibration"
        case .calibrationSaved:
            return "Calibration saved"
        case .resetCalibration:
            return "Reset Calibration"
        case .recording:
            return "Recording"
        case .playerTarget:
            return "Player Target"
        case .detectionSettings:
            return "Detection Settings"
        case .sensitivity:
            return "Sensitivity"
        case .useSystemPlayPauseFallback:
            return "Use system Play/Pause key as fallback"
        case .fallbackNote:
            return "The fallback is global and can affect music apps. It is used only after targeted browser video control fails."
        case .noBrowserVideoTargetSelected:
            return "No browser video target selected."
        case .allowed:
            return "Allowed"
        case .notRequested:
            return "Not requested"
        case .deniedInSystemSettings:
            return "Denied in System Settings"
        case .restrictedBySystemPolicy:
            return "Restricted by system policy"
        case .unknown:
            return "Unknown"
        case .builtInDisplay:
            return "Built-in Display"
        case .display:
            return "Display"
        case .ready:
            return "Ready."
        case .calibrationInstructions:
            return "Record one play clip and three away clips."
        case .cameraPermissionRequired:
            return "Camera permission is required."
        case .calibrationRequiredBeforeDetection:
            return "Calibration is required before detection."
        case .detectionRunning:
            return "Detection running."
        case .detectionPaused:
            return "Detection paused."
        case .cameraPermissionRequiredBeforeCalibration:
            return "Camera permission is required before calibration."
        case .recordPlayBeforeAwayClips:
            return "Record the play clip before away clips."
        case .calibrationComplete:
            return "Calibration complete."
        case .pausedSelectedVideo:
            return "Paused selected video."
        case .selectedVideoAlreadyPaused:
            return "Selected video was already paused."
        case .resumedSelectedVideo:
            return "Resumed selected video."
        case .startedSelectedVideo:
            return "Started selected video."
        case .resumeRequestedVerifyingPlayback:
            return "Resume requested; verifying playback."
        case .retryingVideoResume:
            return "Retrying video resume."
        case .sentMediaFallbackToResume:
            return "Sent system Play/Pause fallback to resume selected video."
        case .resumeStillPausedEnableFallback:
            return "Resume is still paused. Enable Media Key Fallback if this site blocks scripted play."
        case .mediaKeyFallbackDidNotConfirm:
            return "Media key fallback did not confirm playback."
        case .calibrationRequiredShort:
            return "Calibration required."
        }
    }

    private func chineseText(_ key: AppTextKey) -> String {
        switch key {
        case .openVibePlayer:
            return "打开 Vibe Player"
        case .pauseDetection:
            return "暂停检测"
        case .startDetection:
            return "开始检测"
        case .previewGlow:
            return "预览光效"
        case .showDisplayMarkers:
            return "显示屏幕标记"
        case .mediaKeyFallback:
            return "媒体键备用控制"
        case .quit:
            return "退出"
        case .language:
            return "语言"
        case .start:
            return "开始"
        case .pause:
            return "暂停"
        case .permissions:
            return "权限"
        case .camera:
            return "摄像头"
        case .request:
            return "请求权限"
        case .openSettings:
            return "打开设置"
        case .systemMediaKeyFallback:
            return "系统媒体键备用控制"
        case .mediaFallbackEnabledDetail:
            return "默认启用；仅在浏览器视频控制失败时使用"
        case .mediaFallbackOptionalDetail:
            return "可选的全局播放/暂停备用控制"
        case .enabled:
            return "已启用"
        case .enable:
            return "启用"
        case .browserAutomation:
            return "浏览器自动化"
        case .browserAutomationDetail:
            return "Vibe Player 首次控制 Safari 或 Chrome 时，macOS 会请求权限"
        case .captureTarget:
            return "捕获目标"
        case .playbackDisplay:
            return "播放屏幕"
        case .showMarkers:
            return "显示标记"
        case .calibration:
            return "校准"
        case .calibrationSaved:
            return "校准已保存"
        case .resetCalibration:
            return "重置校准"
        case .recording:
            return "录制中"
        case .playerTarget:
            return "播放目标"
        case .detectionSettings:
            return "检测设置"
        case .sensitivity:
            return "灵敏度"
        case .useSystemPlayPauseFallback:
            return "使用系统播放/暂停键作为备用控制"
        case .fallbackNote:
            return "备用控制是全局操作，可能影响音乐 App。它只会在定向浏览器视频控制失败后使用。"
        case .noBrowserVideoTargetSelected:
            return "尚未选择浏览器视频目标。"
        case .allowed:
            return "已允许"
        case .notRequested:
            return "尚未请求"
        case .deniedInSystemSettings:
            return "已在系统设置中拒绝"
        case .restrictedBySystemPolicy:
            return "受系统策略限制"
        case .unknown:
            return "未知"
        case .builtInDisplay:
            return "内建显示器"
        case .display:
            return "显示器"
        case .ready:
            return "已就绪。"
        case .calibrationInstructions:
            return "请录制 1 段播放样本和 3 段离开样本。"
        case .cameraPermissionRequired:
            return "需要摄像头权限。"
        case .calibrationRequiredBeforeDetection:
            return "开始检测前需要先完成校准。"
        case .detectionRunning:
            return "检测运行中。"
        case .detectionPaused:
            return "检测已暂停。"
        case .cameraPermissionRequiredBeforeCalibration:
            return "校准前需要摄像头权限。"
        case .recordPlayBeforeAwayClips:
            return "请先录制播放样本，再录制离开样本。"
        case .calibrationComplete:
            return "校准完成。"
        case .pausedSelectedVideo:
            return "已暂停所选视频。"
        case .selectedVideoAlreadyPaused:
            return "所选视频已经暂停。"
        case .resumedSelectedVideo:
            return "已恢复所选视频。"
        case .startedSelectedVideo:
            return "已开始播放所选视频。"
        case .resumeRequestedVerifyingPlayback:
            return "已请求恢复播放；正在确认播放状态。"
        case .retryingVideoResume:
            return "正在重试恢复视频播放。"
        case .sentMediaFallbackToResume:
            return "已发送系统播放/暂停备用按键来恢复所选视频。"
        case .resumeStillPausedEnableFallback:
            return "视频仍处于暂停状态。如果网站阻止脚本播放，请启用媒体键备用控制。"
        case .mediaKeyFallbackDidNotConfirm:
            return "媒体键备用控制未能确认视频已播放。"
        case .calibrationRequiredShort:
            return "需要校准。"
        }
    }

    private func translatedExtractionFailure(_ message: String) -> String {
        switch message {
        case "No camera device found.":
            return "未找到摄像头设备。"
        case "Could not add camera input.":
            return "无法添加摄像头输入。"
        case "Could not add camera output.":
            return "无法添加摄像头输出。"
        default:
            return message
        }
    }

    private func translatedBrowserMessage(_ message: String) -> String {
        switch message {
        case "No browser window":
            return "没有浏览器窗口。"
        case "Could not create AppleScript.":
            return "无法创建 AppleScript。"
        default:
            return message
        }
    }
}
