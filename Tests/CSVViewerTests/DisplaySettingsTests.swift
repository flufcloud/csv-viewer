import XCTest

@testable import CSVViewer

final class DisplaySettingsTests: XCTestCase {
  func testMarkdownRendererRemovesFormattingMarkersFromDisplayedText() {
    let rendered = MarkdownRenderer.render("A **bold** value with *emphasis* and `code`")

    XCTAssertEqual(String(rendered.characters), "A bold value with emphasis and code")
  }

  func testMarkdownRendererPreservesWhitespaceAndLineBreaks() {
    let rendered = MarkdownRenderer.render("first line\n  second line")

    XCTAssertEqual(String(rendered.characters), "first line\n  second line")
  }

  func testThemeColorSchemes() {
    XCTAssertNil(AppTheme.system.colorScheme)
    XCTAssertEqual(AppTheme.light.colorScheme, .light)
    XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
  }
}
