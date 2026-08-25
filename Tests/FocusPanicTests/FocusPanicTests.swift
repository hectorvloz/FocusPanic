import XCTest
@testable import FocusPanic

final class FocusPanicTests: XCTestCase {
    
    func testFocusSessionCalculation() {
        let session = FocusSession(durationMinutes: 25, presetName: "Pomodoro TDAH")
        XCTAssertEqual(session.originalDurationSeconds, 1500)
        XCTAssertFalse(session.isFinished)
        XCTAssertGreaterThan(session.remainingSeconds, 0)
    }
    
    func testEmergencyCodeGenerator() {
        let code = EmailService.shared.generateEmergencyCode()
        XCTAssertEqual(code.count, 6)
        XCTAssertNotNil(Int(code))
    }
    
    func testDefaultPresetsAvailability() {
        let presets = FocusPreset.defaultPresets
        XCTAssertGreaterThanOrEqual(presets.count, 4)
        XCTAssertTrue(presets.contains { $0.durationMinutes == 25 })
    }
}
