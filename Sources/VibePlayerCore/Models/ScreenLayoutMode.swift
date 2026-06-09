import Foundation

public enum ScreenLayoutMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case horizontal
    case vertical
    case mixed

    public var id: String { rawValue }
}
