import CoreGraphics
import XCTest
@testable import Outcast

final class MovementSystemTests: XCTestCase {
    private let movementSystem = MovementSystem()
    private let roomBounds = RoomBounds(rect: CGRect(x: 10, y: 10, width: 180, height: 120))

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
}

