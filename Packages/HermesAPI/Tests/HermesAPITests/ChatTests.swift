import XCTest
@testable import HermesAPI

final class ChatTests: XCTestCase {

    func testDecodeSessionsResponse() throws {
        let json = Data("""
        {"sessions":[
           {"id":"abc","title":"Build the app","model":"claude-opus-4-8",
            "message_count":12,"preview":"hey","last_active":1.0,"is_active":true,"archived":false},
           {"id":"def","title":null,"model":null,"message_count":0,"preview":"first msg"}
        ],"total":2,"limit":40,"offset":0}
        """.utf8)
        let resp = try JSONDecoder().decode(SessionsResponse.self, from: json)
        XCTAssertEqual(resp.sessions.count, 2)
        XCTAssertEqual(resp.sessions[0].displayTitle, "Build the app")
        XCTAssertTrue(resp.sessions[0].isActive)
        // Null title falls back to preview.
        XCTAssertEqual(resp.sessions[1].displayTitle, "first msg")
    }

    func testDecodeMessagesResponse() throws {
        let json = Data("""
        {"session_id":"abc","messages":[
          {"id":1,"role":"user","content":"hello","timestamp":1.0},
          {"id":2,"role":"assistant","content":"hi there","token_count":5,"timestamp":2.0},
          {"id":3,"role":"tool","tool_name":"bash","content":"ls","timestamp":3.0}
        ]}
        """.utf8)
        let resp = try JSONDecoder().decode(MessagesResponse.self, from: json)
        XCTAssertEqual(resp.messages.count, 3)
        XCTAssertEqual(resp.messages[0].role, .user)
        XCTAssertEqual(resp.messages[1].tokenCount, 5)
        XCTAssertEqual(resp.messages[2].toolName, "bash")
    }

    func testGatewayEventMapping() {
        XCTAssertEqual(HermesGateway.map(type: "message.delta", payload: ["text": "ab"]),
                       .messageDelta("ab"))
        XCTAssertEqual(HermesGateway.map(type: "message.complete", payload: ["text": "done", "status": "ok"]),
                       .messageComplete(text: "done", status: "ok"))
        XCTAssertEqual(HermesGateway.map(type: "tool.start", payload: ["name": "bash", "context": "ls"]),
                       .toolStart(name: "bash", context: "ls"))
        XCTAssertEqual(HermesGateway.map(type: "gateway.ready", payload: [:]), .ready)
        XCTAssertEqual(HermesGateway.map(type: "totally.unknown", payload: [:]),
                       .other(type: "totally.unknown"))
    }

    func testWebsocketURLDerivation() {
        let http = HermesGateway.websocketURL(from: URL(string: "http://senuls-nas:8765")!, token: "t")
        XCTAssertEqual(http.scheme, "ws")
        XCTAssertEqual(http.path, "/api/ws")
        XCTAssertTrue(http.query?.contains("token=t") ?? false)

        let https = HermesGateway.websocketURL(from: URL(string: "https://h.example.com")!, token: nil)
        XCTAssertEqual(https.scheme, "wss")
        XCTAssertNil(https.query)
    }
}
