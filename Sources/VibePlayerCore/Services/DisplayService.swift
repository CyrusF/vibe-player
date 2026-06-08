import AppKit
import CoreGraphics
import Foundation

public final class DisplayService {
    public init() {}

    public func displays() -> [DisplayInfo] {
        NSScreen.screens.enumerated().map { offset, screen in
            let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? UInt32(offset + 1)
            let builtin = CGDisplayIsBuiltin(number) != 0
            let name = builtin ? "Built-in Display" : "Display \(offset + 1)"
            return DisplayInfo(
                id: number,
                index: offset + 1,
                name: name,
                frame: screen.frame,
                isBuiltIn: builtin
            )
        }
    }

    public func recommendedDisplayID() -> UInt32? {
        displays().first(where: \.isBuiltIn)?.id ?? displays().first?.id
    }

    public func screen(for id: UInt32?) -> NSScreen? {
        guard let id else { return NSScreen.main }
        return NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }
    }
}
