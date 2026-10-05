import XCTest
@testable import ClipboardGecmisiYoneticisi

final class ContentClassifierTests: XCTestCase {
    func testClassifyUrl() {
        XCTAssertEqual(ContentClassifier.classify("https://example.com"), .url)
    }

    func testClassifyEmail() {
        XCTAssertEqual(ContentClassifier.classify("user@mail.com"), .email)
    }

    func testClassifyCode() {
        XCTAssertEqual(ContentClassifier.classify("function hello() {}"), .code)
    }

    func testClassifyPlain() {
        XCTAssertEqual(ContentClassifier.classify("hello world"), .plain)
    }
}
