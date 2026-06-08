import AppKit
import CoreGraphics
import Foundation

public protocol MediaKeyControlling {
    func sendPlayPause()
}

public final class MediaKeyService: MediaKeyControlling {
    private let nxKeyTypePlay: Int32 = 16
    private let nxKeyDown: Int32 = 0x0A
    private let nxKeyUp: Int32 = 0x0B
    private let systemDefinedSubtype: Int16 = 8

    public init() {}

    public func sendPlayPause() {
        post(keyState: nxKeyDown)
        post(keyState: nxKeyUp)
    }

    private func post(keyState: Int32) {
        let data1 = (nxKeyTypePlay << 16) | (keyState << 8)
        let flags = NSEvent.ModifierFlags(rawValue: UInt(keyState << 16))
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: systemDefinedSubtype,
            data1: Int(data1),
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}
