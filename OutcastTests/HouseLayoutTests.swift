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

    func testBedInteractionReachIncludesSpaceNearBedFoot() {
        let point = CGPoint(x: layout.bedRect.midX, y: layout.bedRect.minY - 0.4)

        XCTAssertTrue(layout.canInteractWithBed(at: point, reach: GameConstants.bedInteractionReach))
    }

    func testBedInteractionReachExcludesBedAndRoomCenter() {
        let bedCenter = CGPoint(x: layout.bedRect.midX, y: layout.bedRect.midY)

        XCTAssertFalse(layout.canInteractWithBed(at: bedCenter, reach: GameConstants.bedInteractionReach))
        XCTAssertFalse(layout.canInteractWithBed(at: layout.center, reach: GameConstants.bedInteractionReach))
    }
}
