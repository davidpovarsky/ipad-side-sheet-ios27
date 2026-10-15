# Real simulator experiment and evidence criteria

## What this tests

- A genuine SwiftUI `.sheet` with Apple's iPadOS 27-only
  `.presentationPlacement(.trailing)`, placed over **MapKit**.
- Three system-selected presentation detents:
  - Peek: `.height(155)`
  - Medium: `.medium`
  - Full: `.large`
- Actual screenshot captures from an iPadOS 27 simulator and an iOS 27 iPhone
  simulator, plus optional landscape XCTest attachments.
- The app prints its SwiftUI scene's actual `GeometryReader` width in points on
  its map, so screenshots can be inspected for narrow-window validation.
- UI tests print the real window frame and capture labeled images.

## How to run

The repository's [Actions](../../actions) tab has the workflow
`Native iPadOS 27 Side Sheet Screenshots`, triggered on every push to main.

Download the `native-sheet-screenshots` artifact from a completed run.
It includes `screenshots/ipad`, `screenshots/iphone`, logs and result bundles.

A successful CI build and an available screenshot do **not** by themselves
prove that the native sheet is side-positioned. Examine the actual image.

## Important limitation: narrowed iPad window

The user's final request is to **physically resize the same iPad app window**
until it becomes compact and to capture the system adapting the side sheet to a
bottom sheet. That is **not equivalent** to screenshotting a separate iPhone,
rotating the iPad to portrait, or artificially setting the horizontal size class.

This first automated workflow does not yet manipulate an iPadOS window's real
Stage Manager / Windowed Apps resize handle. iPhone captures are **reference
captures only**, not proof of resizing. We must not claim this final condition
passed without showing an authentic iPad before/after pair with changed
`GeometryReader` dimensions and a corresponding native sheet layout change.

To test the missing step manually, run the built app in an iPadOS 27 simulator
with Windowed Apps enabled, resize **the iPad app window itself** using its
system resize handle, and capture both sizes. The iPad must be the same
simulated device in both captures.

## Failure diagnosis

- If `presentationPlacement` is unknown: inspect selected `xcodebuild -version`
  and active iOS SDK. A Swift 26 SDK cannot compile this API.
- If the iPad remains a bottom sheet at full width: Apple may have changed the
  beta behavior or the runtime layout. Treat actual screenshots as evidence.
- If the iPad has only two apparent heights: inspect the screenshot and native
  detent support for this placement. Never replace the system sheet with
  a custom `ZStack` overlay and call it equivalent.
- If UI screenshots are missing but the raw PNGs are present, the test run may
  have failed during interaction; read `logs/ipad-ui-tests.log` and use the raw
  `simctl io screenshot` captures as separate evidence.
