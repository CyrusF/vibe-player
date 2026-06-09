import AVFoundation
import AppKit
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
        .alert(
            store.screenLayoutModeLaunchNoticeTitle,
            isPresented: screenLayoutModeLaunchNoticeBinding
        ) {
            Button(store.text(.gotIt)) {
                store.dismissScreenLayoutModeLaunchNotice()
            }
        } message: {
            Text(store.screenLayoutModeLaunchNoticeMessage)
        }
    }

    private var screenLayoutModeLaunchNoticeBinding: Binding<Bool> {
        Binding(
            get: { store.shouldShowScreenLayoutModeLaunchNotice },
            set: { isPresented in
                if !isPresented {
                    store.dismissScreenLayoutModeLaunchNotice()
                }
            }
        )
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
        Panel(title: store.text(.playbackDisplay), systemImage: "display.2", accessory: {
            Button {
                store.showDisplayMarkers()
            } label: {
                Label(store.text(.showMarkers), systemImage: "number.square")
            }
        }) {
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
            }
        }
    }
}

private struct CalibrationPanelView: View {
    @ObservedObject var store: AppStore
    @State private var pendingScreenLayoutMode: ScreenLayoutMode?
    @State private var isConfirmingScreenLayoutMode = false

    var body: some View {
        Panel(title: store.text(.calibration), systemImage: "scope", accessory: {
            ScreenLayoutModeControl(
                selection: store.screenLayoutMode,
                title: store.screenLayoutModeTitle,
                help: store.screenLayoutModeHelp,
                action: requestScreenLayoutMode
            )
        }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.calibrationMessage)
                    .foregroundStyle(.secondary)

                if store.activeCalibrationClip != nil {
                    ProgressView(value: store.calibrationProgress)
                }

                CalibrationSampleMapView(
                    draft: store.calibrationDraft,
                    calibration: store.calibration,
                    activeClip: store.activeCalibrationClip,
                    currentFeature: store.currentFaceFeature,
                    detectionStatus: store.visualStatus
                )

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
                        if let screenLayoutMode = store.screenLayoutMode {
                            Label(store.calibrationSavedText(screenLayoutMode: screenLayoutMode), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label(store.text(.calibrationSaved), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Spacer()
                    Button(store.text(.resetCalibration)) {
                        store.resetCalibration()
                    }
                }
            }
        }
        .alert(
            store.text(.screenLayoutConfirmationTitle),
            isPresented: $isConfirmingScreenLayoutMode,
            presenting: pendingScreenLayoutMode
        ) { mode in
            Button(store.text(.confirmLayout)) {
                confirmScreenLayoutMode(mode, resetsCalibration: false)
            }
            Button(store.text(.confirmLayoutAndResetCalibration)) {
                confirmScreenLayoutMode(mode, resetsCalibration: true)
            }
            .keyboardShortcut(.defaultAction)
        } message: { _ in
            Text(store.text(.screenLayoutConfirmationMessage))
        }
    }

    private func requestScreenLayoutMode(_ mode: ScreenLayoutMode) {
        guard store.screenLayoutMode != mode else { return }
        guard store.calibration != nil else {
            store.setScreenLayoutMode(mode)
            return
        }
        pendingScreenLayoutMode = mode
        isConfirmingScreenLayoutMode = true
    }

    private func confirmScreenLayoutMode(_ mode: ScreenLayoutMode, resetsCalibration: Bool) {
        store.setScreenLayoutMode(mode)
        if resetsCalibration {
            store.resetCalibration()
        }
        pendingScreenLayoutMode = nil
    }
}

private struct CalibrationSampleMapView: View {
    var draft: CalibrationDraft
    var calibration: FocusCalibration?
    var activeClip: CalibrationClip?
    var currentFeature: FaceFeatures?
    var detectionStatus: DetectionStatus

    private var groups: [CalibrationMapGroup] {
        var draftGroups: [CalibrationMapGroup] = []
        if !draft.playSamples.isEmpty {
            draftGroups.append(CalibrationMapGroup(kind: .play, samples: draft.playSamples))
        }
        for (offset, samples) in draft.pauseGroups.enumerated() where !samples.isEmpty {
            draftGroups.append(CalibrationMapGroup(kind: .away(offset + 1), samples: samples))
        }
        if !draftGroups.isEmpty {
            return draftGroups
        }
        guard let calibration else {
            return []
        }
        return [CalibrationMapGroup(kind: .play, samples: [calibration.playCentroid])]
            + calibration.pauseCentroids.enumerated().map { offset, centroid in
                CalibrationMapGroup(kind: .away(offset + 1), samples: [centroid])
            }
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = CalibrationMapLayout(groups: groups, size: proxy.size)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.10))

                CalibrationMapGrid()
                    .stroke(Color.primary.opacity(0.085), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))

                CalibrationMapPlayTargetView(
                    center: layout.playPosition,
                    isActive: activeClip == .play
                )

                if let currentFeature, calibration != nil {
                    CalibrationMapCurrentFeatureView(
                        status: detectionStatus,
                        position: layout.position(for: currentFeature),
                        playPosition: layout.playPosition
                    )
                }

                ForEach(groups.filter(\.isAway)) { group in
                    CalibrationMapClusterView(
                        group: group,
                        points: group.samples.map { layout.position(for: $0) },
                        playCenter: layout.playPosition,
                        isActive: activeClip == group.clip
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .aspectRatio(2, contentMode: .fit)
    }
}

private struct CalibrationMapGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetX: CGFloat = 18
        let insetY: CGFloat = 12
        let plotMinX = rect.minX + insetX
        let plotMaxX = rect.maxX - insetX
        let plotMinY = rect.minY + insetY
        let plotMaxY = rect.maxY - insetY
        let thirdWidth = (plotMaxX - plotMinX) / 3
        let thirdHeight = (plotMaxY - plotMinY) / 3

        for index in 1...2 {
            let x = plotMinX + (thirdWidth * CGFloat(index))
            path.move(to: CGPoint(x: x, y: plotMinY))
            path.addLine(to: CGPoint(x: x, y: plotMaxY))
        }

        for index in 1...2 {
            let y = plotMinY + (thirdHeight * CGFloat(index))
            path.move(to: CGPoint(x: plotMinX, y: y))
            path.addLine(to: CGPoint(x: plotMaxX, y: y))
        }
        return path
    }
}

private struct CalibrationMapCurrentFeatureView: View {
    private static let playSize = CGSize(width: 104, height: 68)
    private static let currentSize = CGSize(width: 72, height: 46)

    var status: DetectionStatus
    var position: CGPoint
    var playPosition: CGPoint

    private var center: CGPoint {
        status == .active ? playPosition : position
    }

    private var size: CGSize {
        status == .active ? Self.playSize : Self.currentSize
    }

    private var color: Color {
        switch status {
        case .active:
            return .green
        case .inactive:
            return .blue
        case .unknown:
            return .secondary
        case .invalidDistance:
            return .orange
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.opacity(status == .active ? 0.16 : 0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(color.opacity(0.90), lineWidth: 1.8)
            }
            .frame(width: size.width, height: size.height)
            .position(center)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.22), value: center)
            .animation(.easeInOut(duration: 0.22), value: status)
    }
}

private struct CalibrationMapClusterView: View {
    var group: CalibrationMapGroup
    var points: [CGPoint]
    var playCenter: CGPoint
    var isActive: Bool

    private let color = Color.blue
    private let playAvoidanceSize = CGSize(width: 108, height: 72)

    private var clusterRect: CGRect {
        guard let first = points.first else {
            return .zero
        }
        let minX = points.map(\.x).min() ?? first.x
        let maxX = points.map(\.x).max() ?? first.x
        let minY = points.map(\.y).min() ?? first.y
        let maxY = points.map(\.y).max() ?? first.y
        let inset: CGFloat = 34
        let minWidth: CGFloat = 96
        let minHeight: CGFloat = 60
        let width = max(minWidth, (maxX - minX) + inset)
        let height = max(minHeight, (maxY - minY) + inset)
        return CGRect(
            x: ((minX + maxX) / 2) - (width / 2),
            y: ((minY + maxY) / 2) - (height / 2),
            width: width,
            height: height
        )
    }

    var body: some View {
        let rect = clusterRect
        let visualRect = visualRect(for: rect)
        ZStack {
            Ellipse()
                .fill(
                    EllipticalGradient(
                        gradient: Gradient(stops: [
                            .init(color: color.opacity(isActive ? 0.36 : 0.26), location: 0.00),
                            .init(color: color.opacity(isActive ? 0.32 : 0.22), location: 0.50),
                            .init(color: color.opacity(isActive ? 0.15 : 0.09), location: 0.78),
                            .init(color: color.opacity(0.02), location: 0.94),
                            .init(color: color.opacity(0.00), location: 1.00)
                        ]),
                        center: .center,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.50
                    )
                )
                .frame(width: visualRect.width, height: visualRect.height)
                .position(x: visualRect.midX, y: visualRect.midY)

            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(color.opacity(0.72))
                    .frame(width: 5, height: 5)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 0.8)
                    }
                    .position(visualPoint(point))
            }

            Text(group.label)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .frame(minWidth: 25, minHeight: 25)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(color.opacity(0.58), lineWidth: 1)
                }
                .position(x: visualRect.midX, y: visualRect.midY)
        }
    }

    private func visualRect(for rect: CGRect) -> CGRect {
        rect.offsetBy(dx: visualOffset.width, dy: visualOffset.height)
    }

    private func visualPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + visualOffset.width, y: point.y + visualOffset.height)
    }

    private var visualOffset: CGSize {
        let rect = clusterRect
        let center = CGPoint(
            x: rect.midX + groupSeparationOffset.width,
            y: rect.midY + groupSeparationOffset.height
        )
        let dx = center.x - playCenter.x
        let dy = center.y - playCenter.y
        let overlapsPlayArea = abs(dx) < playAvoidanceSize.width / 2
            && abs(dy) < playAvoidanceSize.height / 2
        guard overlapsPlayArea else {
            return groupSeparationOffset
        }

        let distance = max(0.001, sqrt((dx * dx) + (dy * dy)))
        let fallbackX: CGFloat = group.awayIndex == 1 ? -1 : 1
        let unitX = abs(dx) < 0.001 ? fallbackX : dx / distance
        let unitY = abs(dy) < 0.001 ? 0.55 : dy / distance
        return CGSize(
            width: groupSeparationOffset.width + (unitX * 34),
            height: groupSeparationOffset.height + (unitY * 28)
        )
    }

    private var groupSeparationOffset: CGSize {
        switch group.awayIndex {
        case 1:
            return CGSize(width: 12, height: 0)
        case 2:
            return CGSize(width: -12, height: 0)
        case 3:
            return CGSize(width: 0, height: 9)
        default:
            return .zero
        }
    }
}

private struct CalibrationMapPlayTargetView: View {
    var center: CGPoint
    var isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.green.opacity(isActive ? 0.22 : 0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.green, lineWidth: isActive ? 3 : 2)
            }
            .frame(width: 104, height: 68)
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isActive ? 0.34 : 0.24))
                        .frame(width: 42, height: 42)
                        .blur(radius: 8)

                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.white.opacity(isActive ? 0.52 : 0.38), radius: 7)
                        .shadow(color: Color.black.opacity(0.24), radius: 4, y: 2)
                }
            }
            .position(center)
    }
}

private struct CalibrationMapGroup: Identifiable {
    enum Kind: Equatable {
        case play
        case away(Int)
    }

    var kind: Kind
    var samples: [FaceFeatures]

    var id: String {
        switch kind {
        case .play:
            return "play"
        case .away(let index):
            return "away-\(index)"
        }
    }

    var clip: CalibrationClip {
        switch kind {
        case .play:
            return .play
        case .away(let index):
            return .away(index)
        }
    }

    var isAway: Bool {
        if case .away = kind {
            return true
        }
        return false
    }

    var label: String {
        switch kind {
        case .play:
            return "X"
        case .away(let index):
            return "\(index)"
        }
    }

    var awayIndex: Int {
        if case .away(let index) = kind {
            return index
        }
        return 0
    }
}

private struct CalibrationMapLayout {
    private static let horizontalAngleRadius = 2.35
    private static let verticalAngleRadius = 0.72
    private static let plotScale = 0.42

    private let plotRect: CGRect
    private let playAnchor: (horizontal: Double, vertical: Double)

    var playPosition: CGPoint {
        CGPoint(x: plotRect.midX, y: plotRect.midY)
    }

    init(groups: [CalibrationMapGroup], size: CGSize) {
        plotRect = CGRect(
            x: 20,
            y: 16,
            width: max(1, size.width - 40),
            height: max(1, size.height - 32)
        )
        let playPoints = groups
            .first { $0.kind == .play }?
            .samples
            .map { FaceFeatures.layoutAxisPoint($0) } ?? []
        let anchor = Self.meanPoint(playPoints)

        playAnchor = anchor
    }

    func position(for sample: FaceFeatures) -> CGPoint {
        let point = FaceFeatures.layoutAxisPoint(sample)
        let horizontal = CGFloat(Self.sphericalAxis(point.horizontal - playAnchor.horizontal, angleRadius: Self.horizontalAngleRadius))
        let vertical = CGFloat(Self.sphericalAxis(point.vertical - playAnchor.vertical, angleRadius: Self.verticalAngleRadius))
        return CGPoint(
            x: plotRect.midX - (plotRect.width * Self.plotScale * horizontal),
            y: plotRect.midY - (plotRect.height * Self.plotScale * vertical)
        )
    }

    private static func meanPoint(_ points: [(horizontal: Double, vertical: Double)]) -> (horizontal: Double, vertical: Double) {
        guard !points.isEmpty else {
            return (0, 0)
        }
        let count = Double(points.count)
        return (
            horizontal: points.reduce(0) { $0 + $1.horizontal } / count,
            vertical: points.reduce(0) { $0 + $1.vertical } / count
        )
    }

    private static func sphericalAxis(_ delta: Double, angleRadius: Double) -> Double {
        let angle = min(.pi / 2, abs(delta) / angleRadius * (.pi / 2))
        return (delta < 0 ? -1 : 1) * sin(angle)
    }
}

private struct ScreenLayoutModeControl: View {
    @State private var hoveredMode: ScreenLayoutMode?

    var selection: ScreenLayoutMode?
    var title: (ScreenLayoutMode) -> String
    var help: (ScreenLayoutMode) -> String
    var action: (ScreenLayoutMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ScreenLayoutMode.allCases) { mode in
                let isSelected = selection == mode
                Button {
                    action(mode)
                } label: {
                    ScreenLayoutModeIcon(mode: mode)
                        .frame(width: 30, height: 22)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 38, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                }
                .onHover { isHovering in
                    if isHovering {
                        hoveredMode = mode
                    } else if hoveredMode == mode {
                        hoveredMode = nil
                    }
                }
                .help(help(mode))
                .accessibilityLabel(title(mode))
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .bottom) {
            if let hoveredMode {
                ScreenLayoutModeTooltip(text: help(hoveredMode))
                    .offset(y: 34)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredMode)
        .zIndex(5)
    }
}

private struct ScreenLayoutModeTooltip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.20), radius: 6, y: 3)
            .allowsHitTesting(false)
    }
}

private struct ScreenLayoutModeIcon: View {
    var mode: ScreenLayoutMode

    var body: some View {
        GeometryReader { proxy in
            switch mode {
            case .horizontal:
                ScreenGlyph()
                    .frame(width: proxy.size.width * 0.38, height: proxy.size.height * 0.42)
                    .position(x: proxy.size.width * 0.32, y: proxy.size.height * 0.48)
                ScreenGlyph()
                    .frame(width: proxy.size.width * 0.38, height: proxy.size.height * 0.42)
                    .position(x: proxy.size.width * 0.68, y: proxy.size.height * 0.48)
            case .vertical:
                ScreenGlyph()
                    .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 0.34)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.32)
                ScreenGlyph()
                    .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 0.34)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.68)
            case .mixed:
                ScreenGlyph()
                    .frame(width: proxy.size.width * 0.40, height: proxy.size.height * 0.36)
                    .position(x: proxy.size.width * 0.38, y: proxy.size.height * 0.38)
                ScreenGlyph()
                    .frame(width: proxy.size.width * 0.40, height: proxy.size.height * 0.36)
                    .position(x: proxy.size.width * 0.62, y: proxy.size.height * 0.62)
            }
        }
    }
}

private struct ScreenGlyph: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .strokeBorder(lineWidth: 1.5)
            .overlay(alignment: .bottom) {
                Capsule()
                    .frame(width: 7, height: 1.5)
                    .offset(y: 3.5)
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

private struct Panel<Content: View, Accessory: View>: View {
    var title: String
    var systemImage: String
    var accessory: Accessory
    var content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) where Accessory == EmptyView {
        self.title = title
        self.systemImage = systemImage
        self.accessory = EmptyView()
        self.content = content()
    }

    init(
        title: String,
        systemImage: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(title, systemImage: systemImage)
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 12)
                accessory
            }
            content
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
