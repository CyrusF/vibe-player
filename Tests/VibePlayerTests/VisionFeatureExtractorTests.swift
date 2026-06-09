import CoreGraphics
import XCTest
@testable import VibePlayerCore

final class VisionFeatureExtractorTests: XCTestCase {
    func testPrimaryFaceIndexChoosesDominantLargestFace() {
        let boxes = [
            CGRect(x: 0.10, y: 0.20, width: 0.12, height: 0.12),
            CGRect(x: 0.35, y: 0.20, width: 0.30, height: 0.30),
            CGRect(x: 0.70, y: 0.20, width: 0.10, height: 0.10)
        ]

        XCTAssertEqual(VisionFeatureExtractor.primaryFaceIndex(in: boxes), 1)
    }

    func testPrimaryFaceIndexRejectsAmbiguousFaces() {
        let boxes = [
            CGRect(x: 0.10, y: 0.20, width: 0.24, height: 0.24),
            CGRect(x: 0.42, y: 0.20, width: 0.22, height: 0.22)
        ]

        XCTAssertNil(VisionFeatureExtractor.primaryFaceIndex(in: boxes))
    }
}
