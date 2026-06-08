import SwiftUI

public struct FishStatsView: View {
    @ObservedObject private var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { _ in
            VStack(alignment: .leading, spacing: 18) {
                header
                WatchCurveCard(
                    title: store.text(.last14Days),
                    days: store.watchHistoryByDay,
                    language: store.language
                )
                recentSessions
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
        .padding(.bottom, 24)
        .frame(minWidth: 680, minHeight: 500)
        .background(.thickMaterial)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 46, height: 46)
                .background(.teal.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(store.text(.fishStats))
                    .font(.system(size: 28, weight: .semibold))
                if let activeWatchSession = store.activeWatchSession {
                    Text("\(store.text(.activeNow)): \(activeWatchSession.title)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
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

                Button(role: .destructive) {
                    store.clearWatchHistory()
                } label: {
                    Label(store.text(.clearWatchHistory), systemImage: "trash")
                }
                .disabled(store.watchHistory.isEmpty && store.activeWatchSession == nil)
                .controlSize(.small)
            }
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(store.text(.recentWatchSessions), systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if store.watchHistory.isEmpty {
                ContentUnavailableView(
                    store.text(.noWatchHistory),
                    systemImage: "play.slash",
                    description: Text(store.text(.detectionRunning))
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.watchHistory.reversed().prefix(12)) { event in
                            WatchSessionRow(event: event, language: store.language)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
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
    var title: String
    var days: [VideoWatchDay]
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(formatDuration(days.map(\.duration).max() ?? 0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack {
                    ChartGrid()
                    WatchAreaShape(days: days)
                        .fill(
                            LinearGradient(
                                colors: [.teal.opacity(0.22), .blue.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    WatchCurveShape(days: days)
                        .stroke(
                            LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: .teal.opacity(0.18), radius: 6, y: 3)

                    WatchPointDots(days: days)
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
            if let first = days.first {
                Text(formatDay(first.date, language: language))
            }
            Spacer()
            if let last = days.last {
                Text(formatDay(last.date, language: language))
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
    var days: [VideoWatchDay]

    func path(in rect: CGRect) -> Path {
        makeSmoothPath(days: days, in: rect, closesToBottom: false)
    }
}

private struct WatchAreaShape: Shape {
    var days: [VideoWatchDay]

    func path(in rect: CGRect) -> Path {
        makeSmoothPath(days: days, in: rect, closesToBottom: true)
    }
}

private func makeSmoothPath(days: [VideoWatchDay], in rect: CGRect, closesToBottom: Bool) -> Path {
    guard days.count > 1 else { return Path() }
    let maxDuration = max(days.map(\.duration).max() ?? 0, 60)
    let points = days.enumerated().map { index, day in
        let x = rect.minX + (CGFloat(index) / CGFloat(days.count - 1)) * rect.width
        let normalized = day.duration / maxDuration
        let y = rect.maxY - CGFloat(normalized) * rect.height
        return CGPoint(x: x, y: y)
    }

    var path = Path()
    path.move(to: points[0])
    for index in 1..<points.count {
        let previous = points[index - 1]
        let current = points[index]
        let delta = current.x - previous.x
        path.addCurve(
            to: current,
            control1: CGPoint(x: previous.x + delta * 0.42, y: previous.y),
            control2: CGPoint(x: current.x - delta * 0.42, y: current.y)
        )
    }

    if closesToBottom, let first = points.first, let last = points.last {
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
    }

    return path
}

private struct WatchPointDots: View {
    var days: [VideoWatchDay]

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
        guard days.count > 1 else { return [] }
        let maxDuration = max(days.map(\.duration).max() ?? 0, 60)
        return days.enumerated().map { index, day in
            let x = rect.minX + (CGFloat(index) / CGFloat(days.count - 1)) * rect.width
            let normalized = day.duration / maxDuration
            let y = rect.maxY - CGFloat(normalized) * rect.height
            return (CGPoint(x: x, y: y), day.duration)
        }
    }
}

private struct WatchSessionRow: View {
    var event: VideoWatchEvent
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(.teal)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(event.browserName) - \(formatDate(event.startedAt, language: language))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(event.duration))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = Int((interval / 60).rounded())
    if minutes < 60 {
        return "\(minutes)m"
    }
    return "\(minutes / 60)h \(minutes % 60)m"
}

private func formatDay(_ date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language.rawValue)
    formatter.setLocalizedDateFormatFromTemplate("MMM d")
    return formatter.string(from: date)
}

private func formatDate(_ date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language.rawValue)
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
