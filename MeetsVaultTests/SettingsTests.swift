import XCTest
@testable import MeetsVault

final class SettingsTests: XCTestCase {

    override func tearDown() {
        Settings.shared.lastCaptureMode = nil
        super.tearDown()
    }

    func testLastCaptureModeDefaultsToNil() {
        Settings.shared.lastCaptureMode = nil
        XCTAssertNil(Settings.shared.lastCaptureMode)
    }

    func testLastCaptureModeRoundTripsMicOnly() {
        Settings.shared.lastCaptureMode = .micOnly
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micOnly)
    }

    func testLastCaptureModeRoundTripsMicAndSystem() {
        Settings.shared.lastCaptureMode = .micAndSystem
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micAndSystem)
    }

    func testLastCaptureModeOverwritesPreviousValue() {
        Settings.shared.lastCaptureMode = .micOnly
        Settings.shared.lastCaptureMode = .micAndSystem
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micAndSystem)
    }
}
