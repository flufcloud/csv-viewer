import CoreFoundation
import Foundation

enum JSONPathComponent: Equatable {
  case key(String)
  case index(Int)
}

enum JSONFieldValue: Equatable {
  case string(String)
  case number(String)
  case boolean(Bool)
  case null
  case composite(String)

  var displayText: String {
    switch self {
    case .string(let value), .number(let value), .composite(let value):
      value
    case .boolean(let value):
      value ? "true" : "false"
    case .null:
      "null"
    }
  }

  func equals(_ filterText: String) -> Bool {
    let candidate = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
    switch self {
    case .string(let value):
      return value.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive])
        == .orderedSame
    case .number(let value):
      guard let left = Double(value), let right = Double(candidate) else { return false }
      return left == right
    case .boolean(let value):
      return candidate.lowercased() == String(value)
    case .null:
      return candidate.lowercased() == "null"
    case .composite(let value):
      return value == JSONField.normalizedJSON(candidate)
    }
  }
}

enum JSONField {
  static func value(at path: String, in text: String) -> JSONFieldValue? {
    guard let components = pathComponents(path), let data = text.data(using: .utf8) else {
      return nil
    }
    guard var current = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    else {
      return nil
    }

    if let encodedJSON = current as? String,
      let nestedData = encodedJSON.data(using: .utf8),
      let nested = try? JSONSerialization.jsonObject(with: nestedData, options: .fragmentsAllowed)
    {
      current = nested
    }

    for component in components {
      switch component {
      case .key(let key):
        guard let object = current as? [String: Any], let next = object[key] else { return nil }
        current = next
      case .index(let index):
        guard let array = current as? [Any], array.indices.contains(index) else { return nil }
        current = array[index]
      }
    }
    return fieldValue(from: current)
  }

  static func isValidPath(_ path: String) -> Bool {
    pathComponents(path) != nil
  }

  static func normalizedJSON(_ text: String) -> String? {
    guard let data = text.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
      JSONSerialization.isValidJSONObject(object),
      let normalized = try? JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    else {
      return nil
    }
    return String(data: normalized, encoding: .utf8)
  }

  private static func pathComponents(_ path: String) -> [JSONPathComponent]? {
    let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    let path: String
    if trimmedPath.hasPrefix("$.") {
      path = String(trimmedPath.dropFirst(2))
    } else if trimmedPath.hasPrefix("$[") {
      path = String(trimmedPath.dropFirst())
    } else {
      path = trimmedPath
    }
    guard !path.isEmpty else { return nil }

    var components: [JSONPathComponent] = []
    var key = ""
    var expectsComponent = true
    var position = path.startIndex

    while position < path.endIndex {
      let character = path[position]
      if character == "." {
        if !key.isEmpty {
          components.append(.key(key))
          key = ""
        } else if expectsComponent {
          return nil
        }
        expectsComponent = true
      } else if character == "[" {
        if !key.isEmpty {
          components.append(.key(key))
          key = ""
        }
        guard let closingBracket = path[position...].firstIndex(of: "]") else { return nil }
        let numberStart = path.index(after: position)
        guard numberStart < closingBracket,
          let index = Int(path[numberStart..<closingBracket]),
          index >= 0
        else {
          return nil
        }
        components.append(.index(index))
        position = closingBracket
        expectsComponent = false
      } else {
        if !expectsComponent, key.isEmpty { return nil }
        key.append(character)
        expectsComponent = false
      }
      position = path.index(after: position)
    }

    if !key.isEmpty {
      components.append(.key(key))
    } else if expectsComponent {
      return nil
    }
    return components.isEmpty ? nil : components
  }

  private static func fieldValue(from value: Any) -> JSONFieldValue? {
    if value is NSNull {
      return .null
    }
    if let value = value as? String {
      return .string(value)
    }
    if let value = value as? NSNumber {
      if CFGetTypeID(value) == CFBooleanGetTypeID() {
        return .boolean(value.boolValue)
      }
      return .number(value.stringValue)
    }
    guard JSONSerialization.isValidJSONObject(value),
      let data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys),
      let text = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return .composite(text)
  }
}
