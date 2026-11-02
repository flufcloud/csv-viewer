import XCTest

@testable import CSVViewer

final class ColumnLayoutTests: XCTestCase {
  func testDefaultWidthsAreEqualAndFillAvailableSpace() {
    let widths = ColumnLayout.widths(indices: [0, 1, 2], availableWidth: 600, weights: [:])

    XCTAssertEqual(widths[0], 200)
    XCTAssertEqual(widths[1], 200)
    XCTAssertEqual(widths[2], 200)
    XCTAssertEqual(widths.values.reduce(0, +), 600)
  }

  func testResizeAdjustsAdjacentColumnsAndPreservesTotalWidth() {
    let weights = ColumnLayout.resize(
      indices: [0, 1, 2], availableWidth: 600, weights: [:], left: 0, right: 1, delta: 50)
    let widths = ColumnLayout.widths(indices: [0, 1, 2], availableWidth: 600, weights: weights)

    XCTAssertEqual(widths[0], 250)
    XCTAssertEqual(widths[1], 150)
    XCTAssertEqual(widths[2], 200)
    XCTAssertEqual(widths.values.reduce(0, +), 600)
  }

  func testResizeRespectsMinimumWidth() {
    let weights = ColumnLayout.resize(
      indices: [0, 1], availableWidth: 400, weights: [:], left: 0, right: 1, delta: 300)
    let widths = ColumnLayout.widths(indices: [0, 1], availableWidth: 400, weights: weights)

    XCTAssertEqual(widths[0], 328)
    XCTAssertEqual(widths[1], 72)
  }

  func testRestoredColumnKeepsAUsableProportion() {
    let resized = ColumnLayout.resize(
      indices: [0, 1, 2], availableWidth: 600, weights: [:], left: 0, right: 1, delta: 50)
    let resizedWhileHidden = ColumnLayout.resize(
      indices: [0, 1], availableWidth: 600, weights: resized, left: 0, right: 1, delta: 25)
    let restored = ColumnLayout.widths(
      indices: [0, 1, 2], availableWidth: 600, weights: resizedWhileHidden)

    XCTAssertGreaterThan(restored[2] ?? 0, 100)
    XCTAssertEqual(restored.values.reduce(0, +), 600)
  }
}
