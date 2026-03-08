import CoreGraphics
import XCTest
@testable import Outcast

final class MovementSystemTests: XCTestCase {
    private let movementSystem = MovementSystem()
    private let roomBounds = RoomBounds(rect: CGRect(x: 10, y: 10, width: 180, height: 120))
    private let roomBoundsWithHouse = RoomBounds(
        rect: CGRect(x: -50, y: -50, width: 100, height: 100),
        blockedRects: [GameConstants.spawnHouseRect]
    )

    func testMovementIntegratesOverDeltaTime() {
        let position = movementSystem.move(
            from: CGPoint(x: 50, y: 50),
            inputVector: CGVector(dx: 1, dy: 0),
            deltaTime: 0.5,
            speed: 100,
            radius: 10,
            within: roomBounds
        )

        XCTAssertEqual(position.x, 100, accuracy: 0.001)
        XCTAssertEqual(position.y, 50, accuracy: 0.001)
    }

    func testMovementClampsAtRightWall() {
        let position = movementSystem.move(
            from: CGPoint(x: 175, y: 50),
            inputVector: CGVector(dx: 1, dy: 0),
            deltaTime: 1.0,
            speed: 60,
            radius: 10,
            within: roomBounds
        )

        XCTAssertEqual(position.x, 180, accuracy: 0.001)
        XCTAssertEqual(position.y, 50, accuracy: 0.001)
    }

    func testMovementClampsAtBottomLeftCorner() {
        let position = movementSystem.move(
            from: CGPoint(x: 20, y: 20),
            inputVector: CGVector(dx: -0.9, dy: -0.9),
            deltaTime: 1.0,
            speed: 200,
            radius: 10,
            within: roomBounds
        )

        XCTAssertEqual(position.x, 20, accuracy: 0.001)
        XCTAssertEqual(position.y, 20, accuracy: 0.001)
    }

    func testMovementClampsAtTopBarrier() {
        let position = movementSystem.move(
            from: CGPoint(x: 90, y: 120),
            inputVector: CGVector(dx: 0, dy: 1),
            deltaTime: 1.0,
            speed: 100,
            radius: 10,
            within: roomBounds
        )

        XCTAssertEqual(position.x, 90, accuracy: 0.001)
        XCTAssertEqual(position.y, 120, accuracy: 0.001)
    }

    func testMovementStopsAtHouseDoorFace() {
        let radius: CGFloat = 0.48
        let position = movementSystem.move(
            from: CGPoint(x: 0, y: 2.8),
            inputVector: CGVector(dx: 0, dy: 1),
            deltaTime: 1.0,
            speed: 2.0,
            radius: radius,
            within: roomBoundsWithHouse
        )

        XCTAssertEqual(position.x, 0, accuracy: 0.001)
        XCTAssertEqual(position.y, GameConstants.spawnHouseRect.minY - radius, accuracy: 0.001)
    }

    func testMovementStopsAtHouseSideWall() {
        let radius: CGFloat = 0.48
        let position = movementSystem.move(
            from: CGPoint(x: -4.6, y: GameConstants.spawnHouseRect.midY),
            inputVector: CGVector(dx: 1, dy: 0),
            deltaTime: 1.0,
            speed: 2.0,
            radius: radius,
            within: roomBoundsWithHouse
        )

        XCTAssertEqual(position.x, GameConstants.spawnHouseRect.minX - radius, accuracy: 0.001)
        XCTAssertEqual(position.y, GameConstants.spawnHouseRect.midY, accuracy: 0.001)
    }
}
