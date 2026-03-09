import CoreGraphics
import XCTest
@testable import Outcast

final class VectorMathTests: XCTestCase {
    func testMagnitudeMatchesPythagoreanLength() {
        let vector = CGVector(dx: 3, dy: 4)

        XCTAssertEqual(vector.magnitude, 5, accuracy: 0.001)
    }

    func testNormalizedZeroVectorStaysZero() {
        XCTAssertEqual(CGVector.zero.normalized, .zero)
    }

    func testClampedToUnitLeavesShortVectorUnchanged() {
        let vector = CGVector(dx: 0.2, dy: -0.4)

        XCTAssertEqual(vector.clampedToUnit.dx, 0.2, accuracy: 0.001)
        XCTAssertEqual(vector.clampedToUnit.dy, -0.4, accuracy: 0.001)
    }

    func testClampedToUnitNormalizesLongVector() {
        let vector = CGVector(dx: 6, dy: 8)
        let clamped = vector.clampedToUnit

        XCTAssertEqual(clamped.dx, 0.6, accuracy: 0.001)
        XCTAssertEqual(clamped.dy, 0.8, accuracy: 0.001)
        XCTAssertEqual(clamped.magnitude, 1, accuracy: 0.001)
    }
}
