import XCTest
@testable import HermesAPI

final class CronTests: XCTestCase {

    func testCronJobEnabledFromPaused() {
        let job = CronJob(json: ["id": "1", "name": "Lead hunt", "cron": "0 9 * * *", "paused": true])
        XCTAssertEqual(job?.id, "1")
        XCTAssertEqual(job?.schedule, "0 9 * * *")
        XCTAssertEqual(job?.enabled, false)  // paused -> disabled
    }

    func testCronJobEnabledDefaultsTrue() {
        let job = CronJob(json: ["id": "2", "name": "Backup"])
        XCTAssertEqual(job?.enabled, true)
    }

    func testCronJobStatusString() {
        let job = CronJob(json: ["job_id": 7, "status": "paused", "schedule": "*/5 * * * *"])
        XCTAssertEqual(job?.id, "7")              // numeric id coerced to string
        XCTAssertEqual(job?.enabled, false)
    }

    func testCronJobNeedsId() {
        XCTAssertNil(CronJob(json: ["schedule": "* * * * *"]))
    }
}
