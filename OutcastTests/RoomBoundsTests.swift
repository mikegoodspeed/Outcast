import CoreGraphics
import XCTest
@testable import Outcast

final class RoomBoundsTests: XCTestCase {
    private let openBounds = RoomBounds(rect: CGRect(x: 0, y: 0, width: 20, height: 20))
    private let blockedBounds = RoomBounds(
        rect: CGRect(x: 0, y: 0, width: 20, height: 20),
        blockedRects: [CGRect(x: 8, y: 8, width: 4, height: 4)]
    )

    func testClampedRespectsRadiusAtWorldEdges() {
        let clamped = openBounds.clamped(CGPoint(x: -5, y: 25), radius: 2)

        XCTAssertEqual(clamped.x, 2, accuracy: 0.001)
        XCTAssertEqual(clamped.y, 18, accuracy: 0.001)
    }

    func testResolvedPositionAllowsFreeMovementWithoutBlockedRects() {
        let resolved = openBounds.resolvedPosition(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 9, y: 11),
            radius: 1
        )

        XCTAssertEqual(resolved.x, 9, accuracy: 0.001)
        XCTAssertEqual(resolved.y, 11, accuracy: 0.001)
    }

    func testResolvedPositionSlidesAlongBlockedRectWhenHorizontalMovementCollides() {
        let resolved = blockedBounds.resolvedPosition(
            from: CGPoint(x: 6, y: 10),
            to: CGPoint(x: 10, y: 14),
            radius: 1
        )

        XCTAssertEqual(resolved.x, 7, accuracy: 0.001)
        XCTAssertEqual(resolved.y, 14, accuracy: 0.001)
    }

    func testResolvedPositionStopsVerticalMovementAtBlockedRect() {
        let resolved = blockedBounds.resolvedPosition(
            from: CGPoint(x: 10, y: 6),
            to: CGPoint(x: 10, y: 10),
            radius: 1
        )

        XCTAssertEqual(resolved.x, 10, accuracy: 0.001)
        XCTAssertEqual(resolved.y, 7, accuracy: 0.001)
    }

    func testResolvedPositionAllowsTouchingBlockedRectBoundary() {
        let resolved = blockedBounds.resolvedPosition(
            from: CGPoint(x: 6, y: 10),
            to: CGPoint(x: 7, y: 10),
            radius: 1
        )

        XCTAssertEqual(resolved.x, 7, accuracy: 0.001)
        XCTAssertEqual(resolved.y, 10, accuracy: 0.001)
    }
}
