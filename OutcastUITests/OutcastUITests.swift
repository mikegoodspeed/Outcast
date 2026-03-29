import XCTest

final class OutcastUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGameScreenShowsPrimaryControls() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["spawnPrompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["spawnHomeButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["spawnClearNewsButton"].waitForExistence(timeout: 5))

        app.buttons["spawnHomeButton"].tap()

        XCTAssertTrue(app.otherElements["gameView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["virtualJoystick"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["actionButtonA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["actionButtonB"].waitForExistence(timeout: 5))
    }
}
