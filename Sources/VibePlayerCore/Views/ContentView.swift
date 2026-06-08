import AVFoundation
import SwiftUI

public struct ContentView: View {
    @ObservedObject private var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusHeaderView(store: store)
                PermissionChecklistView(store: store)
                DisplaySelectionView(store: store)
                CalibrationPanelView(store: store)
                PlayerTargetPanelView(store: store)
                SettingsPanelView(store: store)
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 760, minHeight: 720)
        .onAppear {
            store.refresh()
        }
    }
}

private struct StatusHeaderView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                Image(systemName: statusIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text("Vibe Player")
                    .font(.system(size: 28, weight: .semibold))
                Text(store.statusTitle(store.status))
                    .foregroundStyle(.secondary)
                Text(store.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                store.isDetectionEnabled ? store.stopDetection() : store.startDetection()
            } label: {
                Label(
                    store.isDetectionEnabled ? store.text(.pause) : store.text(.start),
                    systemImage: store.isDetectionEnabled ? "pause.fill" : "play.fill"
                )
                    .frame(width: 92)
            }
            .buttonStyle(.borderedProminent)

            Button {
                FishStatsWindowController.shared.show(store: store)
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
            .help(store.text(.fishStats))
        }
    }

    private var statusIcon: String {
        switch store.status {
        case .active:
            return "eye.fill"
        case .inactive:
            return "eye.slash.fill"
        case .unknown:
            return "eye"
        case .invalidDistance:
            return "person.crop.circle.badge.exclamationmark"
        }
    }

    private var statusColor: Color {
        switch store.status {
        case .active:
            return .teal
        case .inactive:
            return .blue
        case .unknown:
            return .secondary
        case .invalidDistance:
            return .orange
        }
    }
}

private struct PermissionChecklistView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Panel(title: store.text(.permissions), systemImage: "checkmark.shield") {
            VStack(spacing: 10) {
                PermissionRow(
                    title: store.text(.camera),
                    detail: cameraDetail,
                    isComplete: store.permissions.camera == .authorized,
                    actionTitle: store.permissions.camera == .notDetermined ? store.text(.request) : store.text(.openSettings)
                ) {
                    store.requestCameraAccess()
                }

                PermissionRow(
                    title: store.text(.systemMediaKeyFallback),
                    detail: store.mediaKeyFallbackEnabled ? store.text(.mediaFallbackEnabledDetail) : store.text(.mediaFallbackOptionalDetail),
                    isComplete: store.mediaKeyFallbackEnabled,
                    actionTitle: store.mediaKeyFallbackEnabled ? store.text(.enabled) : store.text(.enable)
                ) {
                    store.mediaKeyFallbackEnabled = true
                }

                PermissionRow(
                    title: store.text(.browserAutomation),
                    detail: store.text(.browserAutomationDetail),
                    isComplete: store.selectedTarget != nil,
                    actionTitle: store.text(.captureTarget),
                    staysEnabledWhenComplete: true
                ) {
                    store.captureTarget(in: .safari)
                }
            }
        }
    }

    private var cameraDetail: String {
        switch store.permissions.camera {
        case .authorized:
            return store.text(.allowed)
        case .notDetermined:
            return store.text(.notRequested)
        case .denied:
            return store.text(.deniedInSystemSettings)
        case .restricted:
            return store.text(.restrictedBySystemPolicy)
        @unknown default:
            return store.text(.unknown)
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var detail: String
    var isComplete: Bool
    var actionTitle: String
    var staysEnabledWhenComplete = false
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? .green : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionTitle, action: action)
                .disabled(isComplete && !staysEnabledWhenComplete)
        }
    }
}

private struct DisplaySelectionView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Panel(title: store.text(.playbackDisplay), systemImage: "display.2") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ForEach(store.displays) { display in
                        Button {
                            store.selectDisplay(display)
                        } label: {
                            HStack {
                                Image(systemName: display.isBuiltIn ? "macbook" : "display")
                                VStack(alignment: .leading) {
                                    Text(store.displayName(for: display))
                                    Text("\(Int(display.frame.width)) x \(Int(display.frame.height))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .overlay(alignment: .topTrailing) {
                            if store.selectedDisplayID == display.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.teal)
                                    .padding(7)
                            }
                        }
                    }
                }

                Button {
                    store.showDisplayMarkers()
                } label: {
                    Label(store.text(.showMarkers), systemImage: "number.square")
                }
            }
        }
    }
}

private struct CalibrationPanelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Panel(title: store.text(.calibration), systemImage: "scope") {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.calibrationMessage)
                    .foregroundStyle(.secondary)

                if store.activeCalibrationClip != nil {
                    ProgressView(value: store.calibrationProgress)
                }

                HStack(spacing: 10) {
                    CalibrationButton(
                        title: store.calibrationClipTitle(.play),
                        sampleText: store.sampleCount(store.calibrationDraft.playSamples.count),
                        recordingText: store.text(.recording),
                        isActive: store.activeCalibrationClip == .play
                    ) {
                        store.beginCalibrationCapture(.play)
                    }

                    ForEach(1...3, id: \.self) { index in
                        CalibrationButton(
                            title: store.calibrationClipTitle(.away(index)),
                            sampleText: store.sampleCount(store.calibrationDraft.pauseGroups[index - 1].count),
                            recordingText: store.text(.recording),
                            isActive: store.activeCalibrationClip == .away(index)
                        ) {
                            store.beginCalibrationCapture(.away(index))
                        }
                    }
                }

                HStack {
                    if store.calibration != nil {
                        Label(store.text(.calibrationSaved), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button(store.text(.resetCalibration)) {
                        store.resetCalibration()
                    }
                }
            }
        }
    }
}

private struct CalibrationButton: View {
    var title: String
    var sampleText: String
    var recordingText: String
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(isActive ? recordingText : sampleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .disabled(isActive)
    }
}

private struct PlayerTargetPanelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Panel(title: store.text(.playerTarget), systemImage: "play.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                if let target = store.selectedTarget {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(target.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(target.browser.displayName) - \(target.url)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Label(
                                store.isPauseBypassActive ? store.text(.rightShiftPauseBypassActive) : store.text(.rightShiftPauseBypass),
                                systemImage: "shift"
                            )
                                .font(.caption)
                                .foregroundStyle(store.isPauseBypassActive ? .teal : .secondary)
                        }

                        Spacer()

                        Button {
                            store.refreshSelectedTarget()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help(store.text(.refreshTarget))
                    }
                } else {
                    Text(store.text(.noBrowserVideoTargetSelected))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    ForEach(BrowserKind.allCases) { browser in
                        Button(browser.displayName) {
                            store.captureTarget(in: browser)
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsPanelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Panel(title: store.text(.detectionSettings), systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                Picker(store.text(.sensitivity), selection: $store.sensitivity) {
                    ForEach(Sensitivity.allCases) { value in
                        Text(store.sensitivityTitle(value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(store.text(.useSystemPlayPauseFallback), isOn: $store.mediaKeyFallbackEnabled)

                Text(store.text(.fallbackNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct Panel<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
            content
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
