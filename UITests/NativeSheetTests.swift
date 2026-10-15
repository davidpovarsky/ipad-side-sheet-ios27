import XCTest
import UIKit

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
    func testTryRealIPadWindowResize() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("A real iPad window can only be resized on iPadOS.")
        }
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--detent", "half"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Jerusalem"].waitForExistence(timeout: 20))

        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        let originalFrame = window.frame
        capture("05-ipad-before-resize")
        print("ACTUAL_IPAD_WINDOW_BEFORE: \(originalFrame)")

        // Real system drag from the bottom-right corner, not a simulated
        // horizontalSizeClass. Requires Windowed Apps mode in the simulator.
        let bottomRight = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.982, dy: 0.98)
        )
        let inward = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.59, dy: 0.79)
        )
        bottomRight.press(forDuration: 0.5, thenDragTo: inward)
        sleep(4)

        let resizedFrame = window.frame
        print("ACTUAL_IPAD_WINDOW_AFTER: \(resizedFrame)")
        if resizedFrame.width > 0 &&
            resizedFrame.width < originalFrame.width * 0.80 {
            capture("06-verified-actual-narrow-ipad-window")
            XCTAssertTrue(app.staticTexts["Jerusalem"].exists)
        } else {
            capture("06-ipad-resize-attempt-not-verified")
            throw XCTSkip(
                "System did not resize the actual iPad window in CI; " +
                "a separate iPhone screenshot must not be represented as proof."
            )
        }
    }

}
