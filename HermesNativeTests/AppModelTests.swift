import XCTest
import HermesAPI
@testable import HermesNative

@MainActor
final class AppModelTests: XCTestCase {

    func testNormalizedURLDefaultsToHTTP() {
        let url = AppModel.normalizedURL("senuls-nas:8765")
        XCTAssertEqual(url?.scheme, "http")
        XCTAssertEqual(url?.host, "senuls-nas")
        XCTAssertEqual(url?.port, 8765)
    }

    func testNormalizedURLKeepsHTTPS() {
        XCTAssertEqual(AppModel.normalizedURL("https://hermes.example.com")?.scheme, "https")
    }

    func testNormalizedURLRejectsBlank() {
        XCTAssertNil(AppModel.normalizedURL("   "))
    }

    func testUnconfiguredWhenStoreEmpty() {
        let model = AppModel(store: InMemoryCredentialStore())
        XCTAssertFalse(model.isConfigured)
        XCTAssertEqual(model.connection, .unconfigured)
    }

    func testConfiguredWhenStoreHasCredential() {
        let cred = HermesCredential(baseURL: URL(string: "http://senuls-nas:8765")!)
        let model = AppModel(store: InMemoryCredentialStore(cred))
        XCTAssertTrue(model.isConfigured)
        XCTAssertEqual(model.connection, .connecting)
    }

    func testSignOutClears() {
        let cred = HermesCredential(baseURL: URL(string: "http://senuls-nas:8765")!)
        let model = AppModel(store: InMemoryCredentialStore(cred))
        model.signOut()
        XCTAssertFalse(model.isConfigured)
        XCTAssertEqual(model.connection, .unconfigured)
    }
}
