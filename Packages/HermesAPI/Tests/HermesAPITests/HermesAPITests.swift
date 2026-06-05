import XCTest
@testable import HermesAPI

final class HermesAPITests: XCTestCase {

    func testDecodeProviders() throws {
        let json = Data("""
        [{"id":"self-hosted","name":"Self Hosted","supports_password":true},
         {"name":"GitHub"}]
        """.utf8)
        let providers = try JSONDecoder().decode([AuthProvider].self, from: json)
        XCTAssertEqual(providers.count, 2)
        XCTAssertEqual(providers[0].id, "self-hosted")
        XCTAssertTrue(providers[0].supportsPassword)
        // Missing id falls back to name; missing supports_password defaults false.
        XCTAssertEqual(providers[1].id, "GitHub")
        XCTAssertFalse(providers[1].supportsPassword)
    }

    func testDecodeSessionToleratesShapes() throws {
        let json = Data(#"{"user_id":"u1","provider":"self-hosted","email":"a@b.c"}"#.utf8)
        let s = try JSONDecoder().decode(Session.self, from: json)
        XCTAssertEqual(s.userId, "u1")
        XCTAssertEqual(s.displayName, "a@b.c")
    }

    func testInMemoryStoreRoundTrip() throws {
        let store = InMemoryCredentialStore()
        XCTAssertNil(store.load())
        let cred = HermesCredential(baseURL: URL(string: "http://senuls-nas:8765")!, sessionToken: "tok")
        try store.save(cred)
        XCTAssertEqual(store.load(), cred)
        try store.clear()
        XCTAssertNil(store.load())
    }

    func testErrorMessages() {
        XCTAssertFalse(HermesError.unauthorized.userMessage.isEmpty)
        XCTAssertTrue(HermesError.http(status: 500).userMessage.contains("500"))
    }

    func testClientProvidersAgainstMock() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/providers")
            let body = Data("[{\"id\":\"x\",\"name\":\"X\"}]".utf8)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, body)
        }
        let client = HermesAPIClient(credential: cred(), session: mockSession())
        let providers = try await client.providers()
        XCTAssertEqual(providers.first?.id, "x")
    }

    func testClientUnauthorizedMapsToError() async {
        MockURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{\"detail\":\"Unauthorized\"}".utf8))
        }
        let client = HermesAPIClient(credential: cred(token: "bad"), session: mockSession())
        do {
            _ = try await client.me()
            XCTFail("expected unauthorized")
        } catch {
            XCTAssertEqual(error as? HermesError, .unauthorized)
        }
    }

    // MARK: - helpers

    private func cred(token: String? = nil) -> HermesCredential {
        HermesCredential(baseURL: URL(string: "http://example.test")!, sessionToken: token)
    }

    private func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: HermesError.network("no handler"))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
