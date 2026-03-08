import XCTest

final class OutcastUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGameScreenShowsPrimaryControls() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["gameView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["virtualJoystick"].waitForExistence(timeout: 5))
    }
}

