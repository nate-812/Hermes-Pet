import XCTest
@testable import HermesMate

final class HermesMateTests: XCTestCase {
    func testJSONValueDecoding() throws {
        let json = """
        {"key": "value", "num": 42, "flag": true}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        XCTAssertEqual(decoded["key"]?.stringValue, "value")
        XCTAssertEqual(decoded["num"]?.intValue, 42)
        XCTAssertEqual(decoded["flag"]?.boolValue, true)
    }

    func testControlPanelFormatsLargeTokenCountsForScanning() {
        XCTAssertEqual(ControlPanelDisplayFormatter.tokens(10_381_043), "10.4M")
        XCTAssertEqual(ControlPanelDisplayFormatter.tokens(563_000), "563K")
        XCTAssertEqual(ControlPanelDisplayFormatter.tokens(950), "950")
    }

    func testControlPanelFormatsCostAndEmptyValues() {
        XCTAssertEqual(ControlPanelDisplayFormatter.cost(12.345), "$12.35")
        XCTAssertEqual(ControlPanelDisplayFormatter.tokens(0), "0")
    }

    func testControlPanelFormatsSystemByteValues() {
        XCTAssertEqual(ControlPanelDisplayFormatter.bytes(UInt64(16 * 1_024 * 1_024 * 1_024)), "16.0 GB")
        XCTAssertEqual(ControlPanelDisplayFormatter.bytes(UInt64(512 * 1_024 * 1_024)), "512 MB")
    }

    func testControlPanelTabsExposeConsoleSections() {
        XCTAssertEqual(ControlPanelTab.allCases.map(\.title), ["Home", "Agents", "Sessions", "System"])
        XCTAssertEqual(ControlPanelTab.home.icon, "gauge.with.dots.needle.50percent")
        XCTAssertEqual(ControlPanelTab.system.icon, "desktopcomputer")
    }
}
