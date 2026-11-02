import Foundation

struct ParsedCSV: Sendable {
  let headers: [String]
  let rows: [[String]]
  let delimiter: Character
  let recoveredIncompleteRecord: Bool
}

enum CSVParserError: LocalizedError {
  case unreadableFile
  case emptyFile

  var errorDescription: String? {
    switch self {
    case .unreadableFile:
      "The file could not be decoded as UTF-8 or ISO Latin 1."
    case .emptyFile:
      "The file does not contain any rows."
    }
  }
}

enum CSVParser {
  static func parse(fileAt url: URL) throws -> ParsedCSV {
    let data = try Data(contentsOf: url)
    guard
      let contents = String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .isoLatin1)
    else {
      throw CSVParserError.unreadableFile
    }
    return try parse(contents)
  }

  static func parse(_ contents: String) throws -> ParsedCSV {
    let delimiter = detectDelimiter(in: contents)
    let result = parseRecords(contents, delimiter: delimiter)
    var records = result.records
    guard !records.isEmpty else {
      throw CSVParserError.emptyFile
    }

    var headers = records.removeFirst()
    let columnCount = max(headers.count, records.map(\.count).max() ?? 0)
    guard columnCount > 0 else {
      throw CSVParserError.emptyFile
    }

    headers += (headers.count..<columnCount).map { "Column \($0 + 1)" }
    headers = normalizedHeaders(headers)
    let rows = records.map { row in
      row + Array(repeating: "", count: max(0, columnCount - row.count))
    }
    return ParsedCSV(
      headers: headers,
      rows: rows,
      delimiter: delimiter,
      recoveredIncompleteRecord: result.recoveredIncompleteRecord
    )
  }

  private static func detectDelimiter(in contents: String) -> Character {
    let candidates: [Character] = [",", "\t", ";", "|"]
    var counts = Dictionary(uniqueKeysWithValues: candidates.map { ($0, 0) })
    var inQuotes = false

    for character in contents.prefix(16_384) {
      if character == "\"" {
        inQuotes.toggle()
      } else if !inQuotes, isLineBreak(character) {
        break
      } else if !inQuotes, counts[character] != nil {
        counts[character, default: 0] += 1
      }
    }
    return candidates.max { counts[$0, default: 0] < counts[$1, default: 0] } ?? ","
  }

  private static func parseRecords(
    _ contents: String,
    delimiter: Character
  ) -> (records: [[String]], recoveredIncompleteRecord: Bool) {
    var records: [[String]] = []
    var record: [String] = []
    var field = ""
    var inQuotes = false
    var recoveredIncompleteRecord = false
    var index = contents.startIndex

    while index < contents.endIndex {
      let character = contents[index]
      if character == "\"" {
        let next = contents.index(after: index)
        if inQuotes, next < contents.endIndex, contents[next] == "\"" {
          field.append("\"")
          index = next
        } else if inQuotes {
          inQuotes = false
        } else if field.allSatisfy(\.isWhitespace) {
          inQuotes = true
        } else {
          field.append(character)
        }
      } else if character == delimiter, !inQuotes {
        record.append(field)
        field = ""
      } else if isLineBreak(character), !inQuotes {
        record.append(field)
        records.append(record)
        record = []
        field = ""

        let next = contents.index(after: index)
        if character == "\r", next < contents.endIndex, contents[next] == "\n" {
          index = next
        }
      } else {
        field.append(character)
      }
      index = contents.index(after: index)
    }

    if inQuotes {
      recoveredIncompleteRecord = true
    }
    if !field.isEmpty || !record.isEmpty {
      record.append(field)
      records.append(record)
    }
    return (records, recoveredIncompleteRecord)
  }

  private static func isLineBreak(_ character: Character) -> Bool {
    character == "\n" || character == "\r" || character == "\r\n"
  }

  private static func normalizedHeaders(_ headers: [String]) -> [String] {
    var occurrences: [String: Int] = [:]
    return headers.enumerated().map { index, header in
      let base =
        header.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "Column \(index + 1)"
        : header
      let count = occurrences[base, default: 0] + 1
      occurrences[base] = count
      return count == 1 ? base : "\(base) (\(count))"
    }
  }
}
