import XCTest

@MainActor
final class NativeSheetTests: XCTestCase {
    private func capture(_ label: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testThreeNativeDetents() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft

        for (index, detent) in ["peek", "half", "full"].enumerated() {
            if app.state != .notRunning {
                app.terminate()
            }
            app.launchArguments = ["--detent", detent]
            app.launch()
            XCTAssertTrue(
                app.navigationBars["Places"].waitForExistence(timeout: 20),
                "Native sheet must really appear on \(detent)"
            )
            sleep(3)
            capture(String(format: "%02d-native-%@", index + 1, detent))
        }
    }

    // A compact iPhone is a reference, NOT proof that an iPad window was resized.
    // On an iPad, resizing must be verified by a changed measured window frame.
    func testWindowInformation() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--detent", "half"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Places"].waitForExistence(timeout: 20))
        sleep(2)
        capture("04-window-geometry-reference")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        print("NATIVE_SHEET_TEST_WINDOW_FRAME: \(window.frame)")
    }
}
