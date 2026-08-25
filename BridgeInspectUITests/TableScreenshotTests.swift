import XCTest

/// Drives navigation to the space table and captures screenshots.
/// Not a correctness test — a way to see the real rendered screen.
final class TableScreenshotTests: XCTestCase {

    func testCaptureSpaceTable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-seedData"]
        app.launch()

        // Projects → Bridge A
        let project = app.staticTexts["Bridge A"]
        XCTAssertTrue(project.waitForExistence(timeout: 10))
        project.tap()

        // Spaces → Space 02 (nine walls, the tallest case)
        let space = app.staticTexts["Space 02"]
        XCTAssertTrue(space.waitForExistence(timeout: 10))
        space.tap()

        // Let the table settle, then capture.
        XCTAssertTrue(app.staticTexts["WALL"].waitForExistence(timeout: 10))
        sleep(1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "SpaceTable"
        shot.lifetime = .keepAlways
        add(shot)

        // Write to a known path so it can be inspected outside the result bundle.
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/table_capture.png"))
    }
}

