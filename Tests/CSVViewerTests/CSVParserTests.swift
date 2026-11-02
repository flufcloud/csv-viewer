import XCTest

@testable import CSVViewer

final class CSVParserTests: XCTestCase {
  func testQuotedFieldsEscapedQuotesAndNewlines() throws {
    let csv =
      "name,notes,count\nAlice,\"hello, world\",2\nBob,\"line 1\nline 2 with \"\"quotes\"\"\",10\n"
    let parsed = try CSVParser.parse(csv)

    XCTAssertEqual(parsed.headers, ["name", "notes", "count"])
    XCTAssertEqual(parsed.rows.count, 2)
    XCTAssertEqual(parsed.rows[0], ["Alice", "hello, world", "2"])
    XCTAssertEqual(parsed.rows[1], ["Bob", "line 1\nline 2 with \"quotes\"", "10"])
    XCTAssertFalse(parsed.recoveredIncompleteRecord)
  }

  func testDelimiterDetectionAndShortRows() throws {
    let parsed = try CSVParser.parse("name;city;note\nA;Paris\nB;Rome;ok")

    XCTAssertEqual(parsed.delimiter, ";")
    XCTAssertEqual(parsed.rows, [["A", "Paris", ""], ["B", "Rome", "ok"]])
  }

  func testEmptyAndDuplicateHeadersAreUsable() throws {
    let parsed = try CSVParser.parse("name,name,\na,b,c")

    XCTAssertEqual(parsed.headers, ["name", "name (2)", "Column 3"])
  }

  func testIncompleteFinalQuotedFieldIsRecovered() throws {
    let csv =
      "id,text,role\n1,\"complete\nmultiline text\",user\n2,\"partial final value\nwith spaces"
    let parsed = try CSVParser.parse(csv)

    XCTAssertEqual(parsed.rows.count, 2)
    XCTAssertEqual(parsed.rows[0], ["1", "complete\nmultiline text", "user"])
    XCTAssertEqual(parsed.rows[1], ["2", "partial final value\nwith spaces", ""])
    XCTAssertTrue(parsed.recoveredIncompleteRecord)
  }

  func testSpacesAndQuotesInsideUnquotedFieldsArePreserved() throws {
    let csv = "id,text\n1,  leading and trailing  \n2,She said \"hello\""
    let parsed = try CSVParser.parse(csv)

    XCTAssertEqual(parsed.rows[0][1], "  leading and trailing  ")
    XCTAssertEqual(parsed.rows[1][1], "She said \"hello\"")
  }

  func testWindowsLineEndingsSeparateRecordsAndRemainInsideQuotedFields() throws {
    let csv = "id,text,role\r\n1,\"line one\r\nline two\",user\r\n2,done,assistant\r\n"
    let parsed = try CSVParser.parse(csv)

    XCTAssertEqual(parsed.headers, ["id", "text", "role"])
    XCTAssertEqual(parsed.rows.count, 2)
    XCTAssertEqual(parsed.rows[0], ["1", "line one\r\nline two", "user"])
    XCTAssertEqual(parsed.rows[1], ["2", "done", "assistant"])
  }

  func testNullFilteringRecognizesEmptyAndCommonMarkers() {
    for value in ["", "   ", "NULL", "nil", "NA", "N/A", "NaN"] {
      XCTAssertTrue(CSVFilter.matches(value, operation: .isNull, filterText: ""))
      XCTAssertFalse(CSVFilter.matches(value, operation: .isNotNull, filterText: ""))
    }

    XCTAssertTrue(CSVFilter.matches("query", operation: .isNotNull, filterText: ""))
    XCTAssertFalse(CSVFilter.matches("query", operation: .isNull, filterText: ""))
  }

  func testUniqueValuesCountNullsAndSortByFrequency() {
    let rows = [
      CSVRow(id: 0, values: ["alpha"]),
      CSVRow(id: 1, values: ["beta"]),
      CSVRow(id: 2, values: ["alpha"]),
      CSVRow(id: 3, values: [""]),
      CSVRow(id: 4, values: ["NULL"]),
    ]
    let values = CSVStatistics.uniqueValues(in: rows, column: 0)

    XCTAssertEqual(values.map(\.value), [nil, "alpha", "beta"])
    XCTAssertEqual(values.map(\.count), [2, 2, 1])
  }
}
