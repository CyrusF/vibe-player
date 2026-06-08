import CoreGraphics
import Foundation

public struct DisplayInfo: Identifiable, Codable, Equatable, Sendable {
    public var id: UInt32
    public var index: Int
    public var name: String
    public var frame: CGRect
    public var isBuiltIn: Bool

    public init(id: UInt32, index: Int, name: String, frame: CGRect, isBuiltIn: Bool) {
        self.id = id
        self.index = index
        self.name = name
        self.frame = frame
        self.isBuiltIn = isBuiltIn
    }
}
