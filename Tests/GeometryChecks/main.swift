import Foundation
import CoreGraphics
import WindowGeometry

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line)
}

func XCTAssertNil<T>(_ actual: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == nil, "Expected nil", file: file, line: line)
}

final class WindowGeometryTests {
    func testHalfScreenLayoutsUseTopLeftCoordinates() {
        let frame = CGRect(x: -1200, y: -700, width: 1200, height: 800)
        XCTAssertEqual(WindowGeometry.target(.left, in: frame), CGRect(x: -1200, y: -700, width: 600, height: 800))
        XCTAssertEqual(WindowGeometry.target(.right, in: frame), CGRect(x: -600, y: -700, width: 600, height: 800))
        XCTAssertEqual(WindowGeometry.target(.top, in: frame), CGRect(x: -1200, y: -700, width: 1200, height: 400))
        XCTAssertEqual(WindowGeometry.target(.bottom, in: frame), CGRect(x: -1200, y: -300, width: 1200, height: 400))
        XCTAssertEqual(WindowGeometry.target(.fill, in: frame), frame)
    }

    func testRepeatedSideCyclesAndStaysAnchored() {
        let frame = CGRect(x: -1200, y: -700, width: 1200, height: 800)
        for placement: Placement in [.left, .right, .top, .bottom] {
            var current = frame
            for fraction: CGFloat in [0.5, 0.75, 0.25, 0.5] {
                current = WindowGeometry.nextTarget(placement, in: frame, current: current)
                XCTAssertEqual(current, WindowGeometry.target(placement, in: frame, fraction: fraction))
                switch placement {
                case .left: XCTAssertEqual(current.minX, frame.minX)
                case .right: XCTAssertEqual(current.maxX, frame.maxX)
                case .top: XCTAssertEqual(current.minY, frame.minY)
                case .bottom: XCTAssertEqual(current.maxY, frame.maxY)
                case .fill: break
                }
            }
        }
        let left = WindowGeometry.target(.left, in: frame)
        XCTAssertEqual(WindowGeometry.nextTarget(.right, in: frame, current: left), WindowGeometry.target(.right, in: frame))
        XCTAssertEqual(WindowGeometry.nextTarget(.fill, in: frame, current: left), frame)
        let adjusted = left.insetBy(dx: 1, dy: 1)
        XCTAssertEqual(WindowGeometry.nextTarget(.left, in: frame, current: adjusted), WindowGeometry.target(.left, in: frame, fraction: 0.75))
        XCTAssertEqual(WindowGeometry.nextTarget(.left, in: frame, current: CGRect(x: 50, y: 50, width: 500, height: 400)), left)
    }

    func testCoordinateConversionForDisplaysAboveBelowAndLeft() {
        XCTAssertEqual(WindowGeometry.accessibilityFrame(CGRect(x: 0, y: 0, width: 1440, height: 900), primaryTop: 900), CGRect(x: 0, y: 0, width: 1440, height: 900))
        XCTAssertEqual(WindowGeometry.accessibilityFrame(CGRect(x: 0, y: 900, width: 1920, height: 1080), primaryTop: 900), CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        XCTAssertEqual(WindowGeometry.accessibilityFrame(CGRect(x: 0, y: -1080, width: 1920, height: 1080), primaryTop: 900), CGRect(x: 0, y: 900, width: 1920, height: 1080))
        XCTAssertEqual(WindowGeometry.accessibilityFrame(CGRect(x: -1920, y: 0, width: 1920, height: 1080), primaryTop: 900), CGRect(x: -1920, y: -180, width: 1920, height: 1080))
    }

    func testVisibleFramePreservesMenuAndDockInsets() {
        let usable = WindowGeometry.accessibilityFrame(CGRect(x: 0, y: 70, width: 1440, height: 806), primaryTop: 900)
        XCTAssertEqual(usable, CGRect(x: 0, y: 24, width: 1440, height: 806))
        XCTAssertEqual(WindowGeometry.target(.bottom, in: usable).maxY, 830)
    }

    func testOddDimensionsStillTileWithoutGaps() {
        let frame = CGRect(x: 0, y: 0, width: 1513, height: 983)
        XCTAssertEqual(WindowGeometry.target(.left, in: frame).maxX, WindowGeometry.target(.right, in: frame).minX)
        XCTAssertEqual(WindowGeometry.target(.top, in: frame).maxY, WindowGeometry.target(.bottom, in: frame).minY)
    }

    func testWindowUsesDisplayWithLargestOverlap() {
        let displays = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: -180, width: 1920, height: 1080)]
        XCTAssertEqual(WindowGeometry.currentDisplay(for: CGRect(x: 1300, y: 100, width: 600, height: 500), displays: displays), 1)
        XCTAssertEqual(WindowGeometry.currentDisplay(for: CGRect(x: 100, y: 100, width: 600, height: 500), displays: displays), 0)
        XCTAssertEqual(WindowGeometry.currentDisplay(for: CGRect(x: -1000, y: 100, width: 300, height: 300), displays: displays), 0)
        XCTAssertEqual(WindowGeometry.currentDisplay(for: CGRect(x: 4000, y: 100, width: 300, height: 300), displays: displays), 1)
        let uneven = [CGRect(x: 0, y: 0, width: 1000, height: 1000), CGRect(x: 1000, y: 0, width: 1000, height: 100)]
        // The center is on display 1, but more window area overlaps display 0.
        XCTAssertEqual(WindowGeometry.currentDisplay(for: CGRect(x: 900, y: -300, width: 400, height: 700), displays: uneven), 0)
        XCTAssertNil(WindowGeometry.currentDisplay(for: .zero, displays: []))
    }
}

let checks = WindowGeometryTests()
checks.testHalfScreenLayoutsUseTopLeftCoordinates()
checks.testRepeatedSideCyclesAndStaysAnchored()
checks.testCoordinateConversionForDisplaysAboveBelowAndLeft()
checks.testVisibleFramePreservesMenuAndDockInsets()
checks.testOddDimensionsStillTileWithoutGaps()
checks.testWindowUsesDisplayWithLargestOverlap()
print("Passed 6 geometry checks (halves, side cycling, coordinates, usable area, odd dimensions, display selection).")
