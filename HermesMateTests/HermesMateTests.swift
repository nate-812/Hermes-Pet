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
}
