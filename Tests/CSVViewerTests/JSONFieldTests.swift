import XCTest

@testable import CSVViewer

final class JSONFieldTests: XCTestCase {
  func testExtractsStringBooleanAndNumberValues() {
    let json = #"{"label":"synthetic","enabled":true,"score":1.5}"#

    XCTAssertEqual(JSONField.value(at: "label", in: json), .string("synthetic"))
    XCTAssertEqual(JSONField.value(at: "enabled", in: json), .boolean(true))
    XCTAssertEqual(JSONField.value(at: "score", in: json), .number("1.5"))
  }

  func testExtractsNestedFieldsAndArrayIndexes() {
    let json = #"{"metadata":{"items":[{"type":"synthetic"}]}}"#

    XCTAssertEqual(
      JSONField.value(at: "metadata.items[0].type", in: json),
      .string("synthetic")
    )
    XCTAssertEqual(
      JSONField.value(at: "$.metadata.items[0].type", in: json),
      .string("synthetic")
    )
    XCTAssertNil(JSONField.value(at: "metadata.items[1].type", in: json))
  }

  func testJSONFilterMatchesSampleClassifierShape() {
    let booleanJSON = #"{"reasoning":"Useful request","classification":true}"#
    let stringJSON = #"{"reasoning":"Open ended","classification":"Multiple"}"#

    XCTAssertTrue(
      CSVFilter.matches(
        booleanJSON,
        operation: .jsonEquals,
        filterText: "true",
        jsonPath: "classification"
      )
    )
    XCTAssertTrue(
      CSVFilter.matches(
        stringJSON,
        operation: .jsonEquals,
        filterText: "multiple",
        jsonPath: "classification"
      )
    )
    XCTAssertTrue(
      CSVFilter.matches(
        stringJSON,
        operation: .jsonContains,
        filterText: "tip",
        jsonPath: "classification"
      )
    )
  }

  func testMissingAndMalformedJSONFieldsDoNotMatch() {
    XCTAssertFalse(
      CSVFilter.matches(
        #"{"other":"synthetic"}"#,
        operation: .jsonNotEquals,
        filterText: "organic",
        jsonPath: "classification"
      )
    )
    XCTAssertFalse(
      CSVFilter.matches(
        "not json",
        operation: .jsonExists,
        filterText: "",
        jsonPath: "classification"
      )
    )
  }

  func testNullFieldsExistAndDoubleEncodedObjectsAreUnwrapped() {
    let nullJSON = #"{"classification":null}"#
    let encodedJSON = #""{\"classification\":\"synthetic\"}""#

    XCTAssertTrue(
      CSVFilter.matches(
        nullJSON,
        operation: .jsonExists,
        filterText: "",
        jsonPath: "classification"
      )
    )
    XCTAssertTrue(
      CSVFilter.matches(
        encodedJSON,
        operation: .jsonEquals,
        filterText: "synthetic",
        jsonPath: "classification"
      )
    )
  }

  func testPathValidationRejectsIncompleteSyntax() {
    XCTAssertTrue(JSONField.isValidPath("metadata.items[0].type"))
    XCTAssertFalse(JSONField.isValidPath("metadata..type"))
    XCTAssertFalse(JSONField.isValidPath("items[abc]"))
    XCTAssertFalse(JSONField.isValidPath("items[0"))
  }

  func testComposedNullAndJSONFiltersRequireEveryRuleToMatch() {
    let filters = [
      FilterRule(column: 0, operation: .isNull),
      FilterRule(
        column: 1,
        operation: .jsonEquals,
        filterText: "synthetic",
        jsonPath: "classification"
      ),
    ]
    let matching = CSVRow(
      id: 0,
      values: ["", #"{"classification":"synthetic"}"#]
    )
    let wrongNullState = CSVRow(
      id: 1,
      values: ["present", #"{"classification":"synthetic"}"#]
    )
    let wrongJSONValue = CSVRow(
      id: 2,
      values: ["", #"{"classification":"organic"}"#]
    )

    XCTAssertTrue(CSVFilter.matches(matching, filters: filters))
    XCTAssertFalse(CSVFilter.matches(wrongNullState, filters: filters))
    XCTAssertFalse(CSVFilter.matches(wrongJSONValue, filters: filters))
  }

  func testIncompleteFilterRulesDoNotHideRows() {
    let row = CSVRow(id: 0, values: ["visible"])
    let filters = [
      FilterRule(column: 0),
      FilterRule(column: 0, operation: .jsonEquals),
    ]

    XCTAssertTrue(CSVFilter.matches(row, filters: filters))
  }
}
