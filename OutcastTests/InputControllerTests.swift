import CoreGraphics
import XCTest
@testable import Outcast

final class InputControllerTests: XCTestCase {
    func testKeyboardSingleAxisVectorIsUnitLength() {
        let inputController = InputController()

        inputController.setKey(.right, isPressed: true)

        XCTAssertEqual(inputController.currentMovementVector().dx, 1, accuracy: 0.001)
        XCTAssertEqual(inputController.currentMovementVector().dy, 0, accuracy: 0.001)
    }

    func testKeyboardDiagonalVectorIsNormalized() {
        let inputController = InputController()

        inputController.setKey(.up, isPressed: true)
        inputController.setKey(.right, isPressed: true)

        let vector = inputController.currentMovementVector()
        XCTAssertEqual(vector.dx, 0.7071, accuracy: 0.001)
        XCTAssertEqual(vector.dy, 0.7071, accuracy: 0.001)
    }

    func testJoystickVectorPreservesAnalogMagnitude() {
        let inputController = InputController()

        inputController.setJoystickVector(CGVector(dx: 0.4, dy: -0.3))

        let vector = inputController.currentMovementVector()
        XCTAssertEqual(vector.dx, 0.4, accuracy: 0.001)
        XCTAssertEqual(vector.dy, -0.3, accuracy: 0.001)
    }

    func testJoystickVectorOverUnitLengthIsClamped() {
        let inputController = InputController()

        inputController.setJoystickVector(CGVector(dx: 3, dy: 4))

        let vector = inputController.currentMovementVector()
        XCTAssertEqual(vector.dx, 0.6, accuracy: 0.001)
        XCTAssertEqual(vector.dy, 0.8, accuracy: 0.001)
    }

    func testMostRecentActiveInputSourceWinsAndFallsBack() {
        let inputController = InputController()

        inputController.setKey(.left, isPressed: true)
        XCTAssertEqual(inputController.currentMovementVector().dx, -1, accuracy: 0.001)

        inputController.setJoystickVector(CGVector(dx: 0.25, dy: 0.8))
        XCTAssertEqual(inputController.currentMovementVector().dx, 0.25, accuracy: 0.001)
        XCTAssertEqual(inputController.currentMovementVector().dy, 0.8, accuracy: 0.001)

        inputController.setJoystickVector(.zero)
        XCTAssertEqual(inputController.currentMovementVector().dx, -1, accuracy: 0.001)
        XCTAssertEqual(inputController.currentMovementVector().dy, 0, accuracy: 0.001)
    }

    func testResetClearsAllActiveInputState() {
        let inputController = InputController()

        inputController.setKey(.up, isPressed: true)
        inputController.setJoystickVector(CGVector(dx: 0.3, dy: 0.6))

        inputController.reset()

        XCTAssertEqual(inputController.currentMovementVector(), .zero)
    }
}
