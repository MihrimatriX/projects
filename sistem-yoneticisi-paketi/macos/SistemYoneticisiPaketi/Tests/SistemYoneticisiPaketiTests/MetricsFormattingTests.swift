import XCTest
@testable import SistemYoneticisiPaketiLib

final class MetricsFormattingTests: XCTestCase {
    func testDiskPercent() {
        let disk = DiskInfo(id: "/", name: "Macintosh HD", usedGb: 120, totalGb: 500)
        XCTAssertEqual(disk.percent, 24, accuracy: 0.1)
    }
}
