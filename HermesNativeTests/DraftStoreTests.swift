import XCTest
@testable import HermesNative

@MainActor
final class DraftStoreTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "DraftStoreTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func testSetAndGetDraft() {
        let store = DraftStore(defaults: makeDefaults())
        store.set("half-written message", for: "sess-1")
        XCTAssertEqual(store.draft(for: "sess-1"), "half-written message")
        XCTAssertEqual(store.draft(for: "other"), "")
    }

    func testEmptyOrWhitespaceClearsDraft() {
        let store = DraftStore(defaults: makeDefaults())
        store.set("text", for: "s")
        store.set("   ", for: "s")
        XCTAssertEqual(store.draft(for: "s"), "")
    }

    func testClear() {
        let store = DraftStore(defaults: makeDefaults())
        store.set("text", for: "s")
        store.clear(for: "s")
        XCTAssertEqual(store.draft(for: "s"), "")
    }

    func testDraftSurvivesReload() {
        let defaults = makeDefaults()
        let first = DraftStore(defaults: defaults)
        first.set("persisted draft", for: "sess-7")
        // A fresh store over the same defaults rehydrates the draft.
        let second = DraftStore(defaults: defaults)
        XCTAssertEqual(second.draft(for: "sess-7"), "persisted draft")
    }

    func testDraftsAreKeyedPerSession() {
        let store = DraftStore(defaults: makeDefaults())
        store.set("for one", for: "one")
        store.set("for two", for: "two")
        XCTAssertEqual(store.draft(for: "one"), "for one")
        XCTAssertEqual(store.draft(for: "two"), "for two")
    }
}
