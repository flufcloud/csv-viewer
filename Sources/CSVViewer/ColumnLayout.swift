import Foundation

enum ColumnLayout {
  static func widths(
    indices: [Int], availableWidth: Double, weights: [Int: Double]
  ) -> [Int: Double] {
    guard !indices.isEmpty else { return [:] }
    let availableWidth = max(0, availableWidth)
    let totalWeight = indices.reduce(0.0) { total, index in
      total + max(0.01, weights[index] ?? 1)
    }
    return Dictionary(
      uniqueKeysWithValues: indices.map { index in
        (index, availableWidth * max(0.01, weights[index] ?? 1) / totalWeight)
      })
  }

  static func resize(
    indices: [Int],
    availableWidth: Double,
    weights: [Int: Double],
    left: Int,
    right: Int,
    delta: Double,
    minimumWidth: Double = 72
  ) -> [Int: Double] {
    guard indices.contains(left), indices.contains(right), indices.count > 1 else {
      return weights
    }

    var currentWidths = widths(indices: indices, availableWidth: availableWidth, weights: weights)
    let minimumWidth = min(minimumWidth, max(0, availableWidth) / Double(indices.count))
    let leftWidth = currentWidths[left] ?? 0
    let rightWidth = currentWidths[right] ?? 0
    let adjustedDelta = min(max(delta, minimumWidth - leftWidth), rightWidth - minimumWidth)
    currentWidths[left] = leftWidth + adjustedDelta
    currentWidths[right] = rightWidth - adjustedDelta

    var result = weights
    let averageWidth = max(0.01, availableWidth / Double(indices.count))
    for index in indices {
      result[index] = (currentWidths[index] ?? 0) / averageWidth
    }
    return result
  }
}
