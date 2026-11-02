import AppKit
import Combine
import Foundation

struct CSVRow: Identifiable, Sendable {
  let id: Int
  let values: [String]
}

enum FilterOperator: String, CaseIterable, Identifiable {
  case contains = "contains"
  case equals = "equals"
  case notEquals = "does not equal"
  case beginsWith = "begins with"
  case endsWith = "ends with"
  case regex = "matches regex"
  case isNull = "is null"
  case isNotNull = "is not null"
  case jsonEquals = "JSON field equals"
  case jsonNotEquals = "JSON field does not equal"
  case jsonContains = "JSON field contains"
  case jsonExists = "JSON field exists"

  var id: Self { self }

  var needsValue: Bool {
    self != .isNull && self != .isNotNull && self != .jsonExists
  }

  var isJSONFilter: Bool {
    switch self {
    case .jsonEquals, .jsonNotEquals, .jsonContains, .jsonExists:
      true
    default:
      false
    }
  }
}

struct FilterRule: Identifiable, Equatable {
  let id: UUID
  var column: Int
  var operation: FilterOperator
  var filterText: String
  var jsonPath: String

  init(
    id: UUID = UUID(),
    column: Int,
    operation: FilterOperator = .contains,
    filterText: String = "",
    jsonPath: String = ""
  ) {
    self.id = id
    self.column = column
    self.operation = operation
    self.filterText = filterText
    self.jsonPath = jsonPath
  }

  var error: String? {
    if operation == .regex, !filterText.isEmpty, (try? Regex(filterText)) == nil {
      return "Invalid regular expression"
    }
    if operation.isJSONFilter {
      if jsonPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "Enter a JSON field path"
      }
      if !JSONField.isValidPath(jsonPath) {
        return "Invalid JSON field path"
      }
    }
    return nil
  }

  var isActive: Bool {
    let hasValue = !operation.needsValue || !filterText.isEmpty
    let hasPath = !operation.isJSONFilter || !jsonPath.isEmpty
    return hasValue && hasPath
  }
}

struct UniqueValue: Identifiable {
  let value: String?
  let count: Int

  var id: String {
    value.map { "value:\($0)" } ?? "null"
  }

  var displayValue: String {
    value ?? "(null)"
  }
}

enum CSVFilter {
  static func matches(
    _ value: String,
    operation: FilterOperator,
    filterText: String,
    jsonPath: String = ""
  ) -> Bool {
    switch operation {
    case .contains:
      return value.localizedCaseInsensitiveContains(filterText)
    case .equals:
      return value.compare(filterText, options: [.caseInsensitive, .diacriticInsensitive])
        == .orderedSame
    case .notEquals:
      return value.compare(filterText, options: [.caseInsensitive, .diacriticInsensitive])
        != .orderedSame
    case .beginsWith:
      return value.range(
        of: filterText,
        options: [.anchored, .caseInsensitive, .diacriticInsensitive]
      )
        != nil
    case .endsWith:
      return value.range(
        of: filterText,
        options: [.anchored, .backwards, .caseInsensitive, .diacriticInsensitive]
      ) != nil
    case .regex:
      return value.range(of: filterText, options: .regularExpression) != nil
    case .isNull:
      return isNull(value)
    case .isNotNull:
      return !isNull(value)
    case .jsonEquals:
      return JSONField.value(at: jsonPath, in: value)?.equals(filterText) == true
    case .jsonNotEquals:
      guard let field = JSONField.value(at: jsonPath, in: value) else { return false }
      return !field.equals(filterText)
    case .jsonContains:
      guard let field = JSONField.value(at: jsonPath, in: value) else { return false }
      return field.displayText.localizedCaseInsensitiveContains(filterText)
    case .jsonExists:
      return JSONField.value(at: jsonPath, in: value) != nil
    }
  }

  static func isNull(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty || ["null", "nil", "na", "n/a", "nan"].contains(normalized)
  }

  static func matches(_ row: CSVRow, filters: [FilterRule]) -> Bool {
    let activeFilters = filters.filter { $0.isActive && $0.error == nil }
    return matchesActive(row, filters: activeFilters)
  }

  static func matchesActive(_ row: CSVRow, filters: [FilterRule]) -> Bool {
    filters.allSatisfy { filter in
      guard row.values.indices.contains(filter.column) else { return false }
      return matches(
        row.values[filter.column],
        operation: filter.operation,
        filterText: filter.filterText,
        jsonPath: filter.jsonPath
      )
    }
  }
}

enum CSVStatistics {
  static func uniqueValues(in rows: [CSVRow], column: Int) -> [UniqueValue] {
    var counts: [String?: Int] = [:]
    for row in rows where row.values.indices.contains(column) {
      let value = row.values[column]
      let key = CSVFilter.isNull(value) ? nil : value
      counts[key, default: 0] += 1
    }
    return counts.map { UniqueValue(value: $0.key, count: $0.value) }.sorted {
      if $0.count != $1.count { return $0.count > $1.count }
      return $0.displayValue.localizedStandardCompare($1.displayValue) == .orderedAscending
    }
  }
}

@MainActor
final class ViewerModel: ObservableObject {
  @Published private(set) var fileURL: URL?
  @Published private(set) var headers: [String] = []
  @Published private(set) var visibleRows: [CSVRow] = []
  @Published private(set) var hiddenColumns: Set<Int> = []
  @Published private(set) var selectedColumns: Set<Int> = []
  @Published private(set) var hiddenRows: Set<Int> = []
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var recoveryNotice: String?
  @Published private(set) var delimiter: Character = ","
  @Published var filters: [FilterRule] = [] {
    didSet { refreshRows() }
  }
  @Published private(set) var uniqueValueColumn = 0
  @Published private(set) var sortColumn: Int?
  @Published private(set) var sortAscending = true

  private var rows: [CSVRow] = []

  var visibleColumnIndices: [Int] {
    headers.indices.filter { !hiddenColumns.contains($0) }
  }

  var totalRowCount: Int { rows.count }

  var canHideSelectedColumns: Bool {
    !selectedColumns.isEmpty && selectedColumns.count < visibleColumnIndices.count
  }

  var filterError: String? {
    filters.compactMap(\.error).first
  }

  var activeFilterCount: Int {
    filters.count { $0.isActive && $0.error == nil }
  }

  var uniqueValues: [UniqueValue] {
    guard headers.indices.contains(uniqueValueColumn) else { return [] }
    return CSVStatistics.uniqueValues(in: visibleRows, column: uniqueValueColumn)
  }

  func open(_ url: URL) {
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let parsed = try await Task.detached(priority: .userInitiated) {
          try CSVParser.parse(fileAt: url)
        }.value
        load(parsed, from: url)
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  func showOpenPanel() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.commaSeparatedText, .plainText]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Choose a CSV or delimited text file"
    if panel.runModal() == .OK, let url = panel.url {
      open(url)
    }
  }

  func clearError() {
    errorMessage = nil
  }

  func addFilter(column: Int? = nil) {
    guard !headers.isEmpty else { return }
    filters.append(FilterRule(column: column ?? 0))
  }

  func removeFilter(_ id: UUID) {
    filters.removeAll { $0.id == id }
  }

  func clearFilters() {
    filters.removeAll()
  }

  func toggleColumn(_ index: Int) {
    if hiddenColumns.contains(index) {
      hiddenColumns.remove(index)
    } else if visibleColumnIndices.count > 1 {
      hiddenColumns.insert(index)
      selectedColumns.remove(index)
    }
  }

  func showAllColumns() {
    hiddenColumns.removeAll()
  }

  func selectColumn(_ index: Int, extending: Bool) {
    guard visibleColumnIndices.contains(index) else { return }
    if extending {
      if selectedColumns.contains(index) {
        selectedColumns.remove(index)
      } else {
        selectedColumns.insert(index)
      }
    } else {
      selectedColumns = [index]
    }
  }

  func clearColumnSelection() {
    selectedColumns.removeAll()
  }

  func hideSelectedColumns() {
    guard canHideSelectedColumns else { return }
    hiddenColumns.formUnion(selectedColumns)
    selectedColumns.removeAll()
  }

  func hideRow(_ id: Int) {
    hiddenRows.insert(id)
    refreshRows()
  }

  func showAllRows() {
    hiddenRows.removeAll()
    refreshRows()
  }

  func setSort(column: Int, ascending: Bool) {
    sortColumn = column
    sortAscending = ascending
    refreshRows()
  }

  func clearSort() {
    sortColumn = nil
    refreshRows()
  }

  func filterForValue(column: Int, value: String) {
    if CSVFilter.isNull(value) {
      filters.append(FilterRule(column: column, operation: .isNull))
    } else {
      filters.append(FilterRule(column: column, operation: .equals, filterText: value))
    }
  }

  func filterForUniqueValue(_ value: UniqueValue) {
    if let value = value.value {
      filterForValue(column: uniqueValueColumn, value: value)
    } else {
      filters.append(FilterRule(column: uniqueValueColumn, operation: .isNull))
    }
  }

  func selectUniqueValueColumn(_ column: Int) {
    uniqueValueColumn = column
  }

  private func load(_ parsed: ParsedCSV, from url: URL) {
    fileURL = url
    headers = parsed.headers
    rows = parsed.rows.enumerated().map { CSVRow(id: $0.offset, values: $0.element) }
    hiddenColumns = []
    selectedColumns = []
    hiddenRows = []
    filters = []
    uniqueValueColumn = 0
    sortColumn = nil
    sortAscending = true
    delimiter = parsed.delimiter
    recoveryNotice =
      parsed.recoveredIncompleteRecord
      ? "Recovered an incomplete quoted field at the end of the file"
      : nil
    refreshRows()
    NSDocumentController.shared.noteNewRecentDocumentURL(url)
  }

  private func refreshRows() {
    guard !rows.isEmpty else {
      visibleRows = []
      return
    }

    let activeFilters = filters.filter { $0.isActive && $0.error == nil }
    var result = rows.filter {
      !hiddenRows.contains($0.id) && CSVFilter.matchesActive($0, filters: activeFilters)
    }
    if let sortColumn, headers.indices.contains(sortColumn) {
      result.sort { lhs, rhs in
        let comparison = compare(lhs.values[sortColumn], rhs.values[sortColumn])
        return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
      }
    }
    visibleRows = result
  }

  private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let left = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
    let right = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
    if let leftNumber = Double(left), let rightNumber = Double(right) {
      if leftNumber < rightNumber { return .orderedAscending }
      if leftNumber > rightNumber { return .orderedDescending }
      return .orderedSame
    }
    return left.localizedStandardCompare(right)
  }
}
