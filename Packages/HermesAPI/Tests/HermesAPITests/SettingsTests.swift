import XCTest
@testable import HermesAPI

final class SettingsTests: XCTestCase {

    func testExtractObjectsFromBareArray() {
        let obj: Any = [["id": "a"], ["id": "b"]]
        XCTAssertEqual(HermesAPIClient.extractObjects(obj).count, 2)
    }

    func testExtractObjectsFromStringArray() {
        let obj: Any = ["claude-opus-4-8", "gpt-5"]
        let out = HermesAPIClient.extractObjects(obj)
        XCTAssertEqual(out.first?["id"] as? String, "claude-opus-4-8")
    }

    func testExtractObjectsFromEnvelope() {
        let obj: Any = ["models": [["id": "x", "provider": "anthropic"]]]
        let out = HermesAPIClient.extractObjects(obj)
        XCTAssertEqual(out.first?["provider"] as? String, "anthropic")
    }

    func testModelOptionLenientParse() {
        let m1 = ModelOption(json: ["model": "claude-opus-4-8", "context_length": 200000])
        XCTAssertEqual(m1?.id, "claude-opus-4-8")
        XCTAssertEqual(m1?.contextWindow, 200000)
        let m2 = ModelOption(json: ["display_name": "GPT-5", "id": "gpt-5", "owned_by": "openai"])
        XCTAssertEqual(m2?.displayName, "GPT-5")
        XCTAssertEqual(m2?.provider, "openai")
        XCTAssertNil(ModelOption(json: ["foo": "bar"]))  // no id-like key
    }
}
