import SwiftUI

public struct FishStatsView: View {
    @ObservedObject private var store: AppStore
    @State private var chartRange: WatchChartRange = .last7Days
    @State private var historyMode: WatchHistoryMode = .visible

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { _ in
            VStack(alignment: .leading, spacing: 18) {
                header
                WatchCurveCard(
                    range: chartRange,
                    points: points(for: chartRange),
                    language: store.language,
                    rangeSelection: $chartRange
                )
                historyControls
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
        .padding(.bottom, 24)
        .frame(minWidth: 680, minHeight: historyMode == .hidden ? 430 : 500)
        .background(.thickMaterial)
        .background(WindowHeightSetter(height: historyMode == .hidden ? 470 : 600))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: historyMode == .masked ? "asterisk" : "chart.xyaxis.line")
                .font(.system(size: historyMode == .masked ? 34 : 26, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 46, height: 46)
                .background(.teal.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(store.text(.fishStats))
                    .font(.system(size: 28, weight: .semibold))
                if let activeWatchSession = store.activeWatchSession {
                    Text("\(store.text(.activeNow)): \(title(activeWatchSession.title, id: activeWatchSession.url))")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if historyMode != .hidden {
                    Text(store.text(.recentWatchSessions))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 10) {
                    StatPill(
                        title: store.text(.todayWatchTime),
                        value: formatDuration(store.totalWatchDurationToday)
                    )
                    StatPill(
                        title: store.text(.weekWatchTime),
                        value: formatDuration(store.totalWatchDurationThisWeek)
                    )
                }
            }
        }
    }

    private var historyModeButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                historyMode = historyMode.next
            }
        } label: {
            Image(systemName: historyMode.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(historyMode.title(in: store.language))
    }

    private var historyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                if historyMode != .hidden {
                    Label(store.text(.recentWatchSessions), systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .transition(.opacity)
                }

                Spacer()

                if historyMode != .hidden {
                    clearHistoryButton
                }

                historyModeButton
            }

            if historyMode != .hidden {
                recentSessions
            }
        }
    }

    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            store.clearWatchHistory()
        } label: {
            Label(store.text(.clearWatchHistory), systemImage: "trash")
        }
        .disabled(store.watchHistory.isEmpty && store.activeWatchSession == nil)
        .controlSize(.small)
        .frame(height: 26)
    }

    private var recentSessions: some View {
        Group {
            let groups = groupedWatchHistory
            if groups.isEmpty {
                ContentUnavailableView(
                    store.text(.noWatchHistory),
                    systemImage: "play.slash",
                    description: Text(store.text(.detectionRunning))
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(groups) { group in
                            WatchSessionRow(
                                group: group,
                                title: title(group.title, id: group.id),
                                language: store.language
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var groupedWatchHistory: [WatchHistoryGroup] {
        var groups: [String: WatchHistoryGroup] = [:]
        for event in store.watchHistory {
            let key = event.title
            if var group = groups[key] {
                group.duration += event.duration
                group.count += 1
                group.startedAt = max(group.startedAt, event.startedAt)
                group.browserName = event.browserName
                groups[key] = group
            } else {
                groups[key] = WatchHistoryGroup(
                    id: key,
                    title: event.title,
                    browserName: event.browserName,
                    startedAt: event.startedAt,
                    duration: event.duration,
                    count: 1
                )
            }
        }
        return groups.values.sorted { first, second in
            first.startedAt > second.startedAt
        }
        .prefix(12)
        .map { $0 }
    }

    private func points(for range: WatchChartRange) -> [VideoWatchPoint] {
        switch range {
        case .last7Days:
            return store.watchHistoryLast7Days
        case .last24Hours:
            return store.watchHistoryLast24Hours
        case .last60Minutes:
            return store.watchHistoryLast60Minutes
        }
    }

    private func title(_ value: String, id: String) -> String {
        historyMode == .masked ? maskTitle(value, seed: stableSeed(id + value)) : value
    }
}

private enum WatchChartRange: String, CaseIterable, Identifiable {
    case last7Days
    case last24Hours
    case last60Minutes

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .last7Days:
            return language.text(.last7Days)
        case .last24Hours:
            return language.text(.last24Hours)
        case .last60Minutes:
            return language.text(.last60Minutes)
        }
    }

    var labelStyle: WatchChartLabelStyle {
        switch self {
        case .last7Days:
            return .day
        case .last24Hours:
            return .hour
        case .last60Minutes:
            return .minute
        }
    }
}

private enum WatchHistoryMode {
    case visible
    case hidden
    case masked

    var next: WatchHistoryMode {
        switch self {
        case .visible:
            return .hidden
        case .hidden:
            return .masked
        case .masked:
            return .visible
        }
    }

    var systemImage: String {
        switch self {
        case .visible:
            return "eye"
        case .hidden:
            return "eye.slash"
        case .masked:
            return "asterisk"
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .visible:
            return language.text(.historyVisibleMode)
        case .hidden:
            return language.text(.historyHiddenMode)
        case .masked:
            return language.text(.historyMaskedMode)
        }
    }
}

private enum WatchChartLabelStyle {
    case day
    case hour
    case minute
}

private struct StatPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(width: 112, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WatchCurveCard: View {
    var range: WatchChartRange
    var points: [VideoWatchPoint]
    var language: AppLanguage
    @Binding var rangeSelection: WatchChartRange

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $rangeSelection) {
                    ForEach(WatchChartRange.allCases) { range in
                        Text(range.title(in: language)).tag(range)
                    }
                }
                .labelsHidden()
                .frame(width: 170)

                Spacer()

                Text(formatDuration(points.map(\.duration).max() ?? 0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack {
                    ChartGrid()
                    WatchAreaShape(points: points)
                        .fill(
                            LinearGradient(
                                colors: [.teal.opacity(0.22), .blue.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    WatchCurveShape(points: points)
                        .stroke(
                            LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: .teal.opacity(0.18), radius: 6, y: 3)

                    WatchPointDots(points: points)
                }
                .overlay(alignment: .bottom) {
                    chartLabels(width: proxy.size.width)
                        .offset(y: 23)
                }
            }
            .frame(height: 190)
            .padding(.bottom, 24)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func chartLabels(width: CGFloat) -> some View {
        HStack {
            if let first = points.first {
                Text(formatTick(first.date, style: range.labelStyle, language: language))
            }
            Spacer()
            if let last = points.last {
                Text(formatTick(last.date, style: range.labelStyle, language: language))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: width)
    }
}

private struct ChartGrid: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(.secondary.opacity(0.12))
                    .frame(height: 1)
                Spacer()
            }
            Rectangle()
                .fill(.secondary.opacity(0.12))
                .frame(height: 1)
        }
    }
}

private struct WatchCurveShape: Shape {
    var points: [VideoWatchPoint]

    func path(in rect: CGRect) -> Path {
        makeSmoothPath(points: points, in: rect, closesToBottom: false)
    }
}

private struct WatchAreaShape: Shape {
    var points: [VideoWatchPoint]

    func path(in rect: CGRect) -> Path {
        makeSmoothPath(points: points, in: rect, closesToBottom: true)
    }
}

private func makeSmoothPath(points: [VideoWatchPoint], in rect: CGRect, closesToBottom: Bool) -> Path {
    guard points.count > 1 else { return Path() }
    let maxDuration = max(points.map(\.duration).max() ?? 0, 60)
    let locations = points.enumerated().map { index, point in
        let x = rect.minX + (CGFloat(index) / CGFloat(points.count - 1)) * rect.width
        let normalized = point.duration / maxDuration
        let y = rect.maxY - CGFloat(normalized) * rect.height
        return CGPoint(x: x, y: y)
    }

    var path = Path()
    path.move(to: locations[0])
    for index in 1..<locations.count {
        let previous = locations[index - 1]
        let current = locations[index]
        let delta = current.x - previous.x
        path.addCurve(
            to: current,
            control1: CGPoint(x: previous.x + delta * 0.42, y: previous.y),
            control2: CGPoint(x: current.x - delta * 0.42, y: current.y)
        )
    }

    if closesToBottom, let first = locations.first, let last = locations.last {
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
    }

    return path
}

private struct WatchPointDots: View {
    var points: [VideoWatchPoint]

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.frame(in: .local))
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(.background)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .fill(point.duration > 0 ? Color.teal : Color.secondary.opacity(0.35))
                            .frame(width: 5, height: 5)
                    }
                    .position(point.location)
            }
        }
    }

    private func chartPoints(in rect: CGRect) -> [(location: CGPoint, duration: TimeInterval)] {
        guard points.count > 1 else { return [] }
        let maxDuration = max(points.map(\.duration).max() ?? 0, 60)
        return points.enumerated().map { index, point in
            let x = rect.minX + (CGFloat(index) / CGFloat(points.count - 1)) * rect.width
            let normalized = point.duration / maxDuration
            let y = rect.maxY - CGFloat(normalized) * rect.height
            return (CGPoint(x: x, y: y), point.duration)
        }
    }
}

private struct WatchHistoryGroup: Identifiable {
    var id: String
    var title: String
    var browserName: String
    var startedAt: Date
    var duration: TimeInterval
    var count: Int
}

private struct WatchSessionRow: View {
    var group: WatchHistoryGroup
    var title: String
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(.teal)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(group.duration))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var subtitle: String {
        let date = formatDate(group.startedAt, language: language)
        guard group.count > 1 else {
            return "\(group.browserName) - \(date)"
        }
        return "\(group.browserName) - \(date) - x\(group.count)"
    }
}

private func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = Int((interval / 60).rounded())
    if minutes < 60 {
        return "\(minutes)m"
    }
    return "\(minutes / 60)h \(minutes % 60)m"
}

private func formatTick(_ date: Date, style: WatchChartLabelStyle, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language.rawValue)
    switch style {
    case .day:
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
    case .hour:
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
    case .minute:
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
    }
    return formatter.string(from: date)
}

private func formatDate(_ date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language.rawValue)
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func maskTitle(_ value: String, seed: UInt64) -> String {
    let characters = Array(value)
    guard characters.count >= 2 else { return value }

    let target = max(2, Int((Double(characters.count) * 0.4).rounded()))
    var masked = Array(repeating: false, count: characters.count)
    var generator = StableRandom(seed: seed)
    var remaining = target
    var attempts = 0

    while remaining > 0 && attempts < characters.count * 5 {
        attempts += 1
        let start = generator.nextInt(upperBound: characters.count)
        guard !characters[start].isWhitespace else { continue }
        let maxLength = min(characters.count - start, max(2, remaining + 1))
        guard maxLength >= 2 else { continue }
        let length = min(max(2, generator.nextInt(upperBound: maxLength) + 1), remaining)
        var applied = 0

        for index in start..<min(start + length, characters.count) where !characters[index].isWhitespace && !masked[index] {
            masked[index] = true
            applied += 1
        }
        remaining -= applied
    }

    return String(characters.enumerated().map { index, character in
        masked[index] ? "●" : character
    })
}

private func stableSeed(_ value: String) -> UInt64 {
    value.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
        (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
}

private struct StableRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value = value ^ (value >> 31)
        return Int(value % UInt64(max(upperBound, 1)))
    }
}

private struct WindowHeightSetter: NSViewRepresentable {
    var height: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let frame = window.frame
            guard abs(frame.height - height) > 1 else { return }
            let newFrame = CGRect(
                x: frame.minX,
                y: frame.maxY - height,
                width: frame.width,
                height: height
            )
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}
