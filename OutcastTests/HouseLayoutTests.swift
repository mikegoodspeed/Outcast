import CoreGraphics
import XCTest
@testable import Outcast

final class HouseLayoutTests: XCTestCase {
    private let layout = GameConstants.spawnHouseLayout

    func testFrontDoorIsCenteredOnHouseEntranceAxis() {
        XCTAssertEqual(layout.frontDoorOpeningRect.midX, 0, accuracy: 0.001)
        XCTAssertEqual(layout.frontDoorOpeningRect.midY, layout.outerRect.minY, accuracy: 0.001)
    }

    func testBlockedRectsExcludeDoorOpenings() {
        XCTAssertFalse(layout.blockedRects.contains { $0.intersects(layout.frontDoorOpeningRect) })
    }

    func testSingleRoomLayoutHasNoInteriorWalls() {
        XCTAssertTrue(layout.interiorWallRects.isEmpty)
    }

    func testBedRectSitsInTopLeftInteriorCorner() {
        XCTAssertGreaterThanOrEqual(layout.bedRect.minX, layout.interiorRect.minX)
        XCTAssertLessThanOrEqual(layout.bedRect.maxY, layout.interiorRect.maxY)
        XCTAssertLessThan(layout.bedRect.midX, layout.interiorRect.midX)
        XCTAssertGreaterThan(layout.bedRect.midY, layout.interiorRect.midY)
    }
}
