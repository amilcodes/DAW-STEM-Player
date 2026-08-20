import XCTest
@testable import StemPlayer

final class StemProjectTests: XCTestCase {
    func testRoleInference() {
        XCTAssertEqual(StemRole.infer(from: "01_DRUMS.wav"), .drums)
        XCTAssertEqual(StemRole.infer(from: "Lead Vocals.flac"), .vocals)
        XCTAssertEqual(StemRole.infer(from: "sub_bass.aif"), .bass)
        XCTAssertEqual(StemRole.infer(from: "guitars.wav"), .instruments)
        XCTAssertEqual(StemRole.infer(from: "mystery.wav"), .custom)
    }

    func testProjectRoundTrip() throws {
        let project = StemProject(title: "Test")
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(StemProject.self, from: data)
        XCTAssertEqual(decoded.title, "Test")
        XCTAssertEqual(decoded.pads.count, 12)
        XCTAssertEqual(decoded.schemaVersion, StemProject.currentSchemaVersion)
    }

    func testLoopDurationNeverReachesZero() {
        let loop = LoopRange(isEnabled: true, startSeconds: 10, endSeconds: 10)
        XCTAssertEqual(loop.duration, 0.05, accuracy: 0.0001)
    }
}
