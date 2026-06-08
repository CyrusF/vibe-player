import AppKit
import SwiftUI

public enum GlowStyle: Equatable, Sendable {
    case active
    case inactive
    case invalid

    var opacity: Double {
        switch self {
        case .active:
            return 0.76
        case .inactive:
            return 0.28
        case .invalid:
            return 0.22
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .active:
            return 6
        case .inactive:
            return 4
        case .invalid:
            return 3.5
        }
    }

    var haloWidth: CGFloat {
        switch self {
        case .active:
            return 13
        case .inactive:
            return 7
        case .invalid:
            return 6
        }
    }

    var coreWidth: CGFloat {
        switch self {
        case .active:
            return 2.4
        case .inactive:
            return 1.4
        case .invalid:
            return 1.2
        }
    }

    var midWidth: CGFloat {
        switch self {
        case .active:
            return 5.5
        case .inactive:
            return 3
        case .invalid:
            return 2.5
        }
    }

    var cornerOpacity: Double {
        switch self {
        case .active:
            return min(1, opacity + 0.24)
        case .inactive:
            return min(1, opacity + 0.16)
        case .invalid:
            return min(1, opacity + 0.12)
        }
    }

    var duration: TimeInterval {
        switch self {
        case .active:
            return 0.72
        case .inactive:
            return 0.42
        case .invalid:
            return 0.35
        }
    }
}

@MainActor
public final class OverlayService {
    private var markerWindows: [NSWindow] = []
    private var glowWindow: NSWindow?

    public init() {}

    public func showDisplayMarkers(displays: [DisplayInfo], selectedID: UInt32?) {
        hideDisplayMarkers()

        for display in displays {
            let rect = CGRect(x: display.frame.minX + 18, y: display.frame.maxY - 84, width: 64, height: 64)
            let window = NSPanel(
                contentRect: rect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.contentView = NSHostingView(rootView: DisplayMarkerView(
                number: display.index,
                isSelected: display.id == selectedID
            ))
            window.orderFrontRegardless()
            markerWindows.append(window)
        }
    }

    public func hideDisplayMarkers() {
        markerWindows.forEach { $0.orderOut(nil) }
        markerWindows.removeAll()
    }

    public func flashGlow(on screen: NSScreen?, style: GlowStyle) {
        guard let screen else { return }
        glowWindow?.orderOut(nil)

        let window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.contentView = NSHostingView(rootView: EdgeGlowView(style: style))
        window.alphaValue = 0
        window.orderFrontRegardless()
        glowWindow = window

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = 1
        } completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + style.duration) { [weak self, weak window] in
                guard let window else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.24
                    window.animator().alphaValue = 0
                } completionHandler: {
                    window.orderOut(nil)
                    if self?.glowWindow === window {
                        self?.glowWindow = nil
                    }
                }
            }
        }
    }
}

private struct DisplayMarkerView: View {
    var number: Int
    var isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.teal : Color.white.opacity(0.75), lineWidth: isSelected ? 3 : 1.5)
                }
            Text("\(number)")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct EdgeGlowView: View {
    var style: GlowStyle

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = max(10, min(15, min(proxy.size.width, proxy.size.height) * 0.014))
            let inset = CGFloat(0.5)

            ZStack {
                outerHalo(cornerRadius: cornerRadius, inset: inset)
                transitionHalo(cornerRadius: cornerRadius, inset: inset)
                roundedCore(cornerRadius: cornerRadius, inset: inset)
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
    }

    private func outerHalo(cornerRadius: CGFloat, inset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(baseGlowGradient.opacity(style.opacity * 0.34), lineWidth: style.haloWidth)
            .blur(radius: style.blurRadius * 0.82)
            .padding(inset)
            .saturation(1.18)
    }

    private func transitionHalo(cornerRadius: CGFloat, inset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(transitionGlowGradient.opacity(style.opacity * 0.64), lineWidth: style.midWidth)
            .blur(radius: max(0.75, style.blurRadius * 0.24))
            .padding(inset)
            .saturation(1.10)
    }

    private func roundedCore(cornerRadius: CGFloat, inset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(coreGlowGradient.opacity(style.opacity * 0.82), lineWidth: style.coreWidth)
            .blur(radius: 0.10)
            .padding(inset)
    }

    private var baseGlowGradient: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: cyan, location: 0.00),
                .init(color: violet, location: 0.07),
                .init(color: hotPink, location: 0.125),
                .init(color: violet, location: 0.18),
                .init(color: aqua, location: 0.25),
                .init(color: violet, location: 0.32),
                .init(color: hotPink, location: 0.375),
                .init(color: violet, location: 0.43),
                .init(color: blue, location: 0.50),
                .init(color: violet, location: 0.57),
                .init(color: hotPink, location: 0.625),
                .init(color: violet, location: 0.68),
                .init(color: aqua, location: 0.75),
                .init(color: violet, location: 0.82),
                .init(color: hotPink, location: 0.875),
                .init(color: violet, location: 0.93),
                .init(color: cyan, location: 1.00)
            ],
            center: .center
        )
    }

    private var transitionGlowGradient: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: nearWhiteBlue.opacity(0.84), location: 0.00),
                .init(color: violet.opacity(0.72), location: 0.07),
                .init(color: hotPink.opacity(0.62), location: 0.125),
                .init(color: violet.opacity(0.72), location: 0.18),
                .init(color: aqua.opacity(0.78), location: 0.25),
                .init(color: violet.opacity(0.72), location: 0.32),
                .init(color: hotPink.opacity(0.62), location: 0.375),
                .init(color: violet.opacity(0.72), location: 0.43),
                .init(color: cyan.opacity(0.78), location: 0.50),
                .init(color: violet.opacity(0.72), location: 0.57),
                .init(color: hotPink.opacity(0.62), location: 0.625),
                .init(color: violet.opacity(0.72), location: 0.68),
                .init(color: aqua.opacity(0.78), location: 0.75),
                .init(color: violet.opacity(0.72), location: 0.82),
                .init(color: hotPink.opacity(0.62), location: 0.875),
                .init(color: violet.opacity(0.72), location: 0.93),
                .init(color: nearWhiteBlue.opacity(0.84), location: 1.00)
            ],
            center: .center
        )
    }

    private var coreGlowGradient: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: nearWhiteBlue.opacity(0.86), location: 0.00),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.07),
                .init(color: nearWhitePink.opacity(0.70), location: 0.125),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.18),
                .init(color: whiteCore.opacity(0.88), location: 0.25),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.32),
                .init(color: nearWhitePink.opacity(0.70), location: 0.375),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.43),
                .init(color: nearWhiteBlue.opacity(0.88), location: 0.50),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.57),
                .init(color: nearWhitePink.opacity(0.70), location: 0.625),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.68),
                .init(color: whiteCore.opacity(0.88), location: 0.75),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.82),
                .init(color: nearWhitePink.opacity(0.70), location: 0.875),
                .init(color: nearWhiteViolet.opacity(0.78), location: 0.93),
                .init(color: nearWhiteBlue.opacity(0.86), location: 1.00)
            ],
            center: .center
        )
    }

    private var cornerPink: Color {
        Color(red: 1.00, green: 0.30, blue: 0.66)
    }

    private var hotPink: Color {
        Color(red: 1.00, green: 0.12, blue: 0.58)
    }

    private var violet: Color {
        Color(red: 0.58, green: 0.28, blue: 1.00)
    }

    private var aqua: Color {
        Color(red: 0.00, green: 0.88, blue: 0.78)
    }

    private var cyan: Color {
        Color(red: 0.10, green: 0.64, blue: 1.00)
    }

    private var blue: Color {
        Color(red: 0.22, green: 0.36, blue: 1.00)
    }

    private var nearWhiteBlue: Color {
        Color(red: 0.78, green: 0.98, blue: 1.00)
    }

    private var nearWhiteViolet: Color {
        Color(red: 0.88, green: 0.82, blue: 1.00)
    }

    private var nearWhitePink: Color {
        Color(red: 1.00, green: 0.82, blue: 0.94)
    }

    private var whiteCore: Color {
        Color(red: 0.94, green: 1.00, blue: 0.98)
    }
}
