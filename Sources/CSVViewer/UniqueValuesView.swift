import SwiftUI

struct UniqueValuesView: View {
  let columnName: String
  let rowCount: Int
  let values: [UniqueValue]
  let applyFilter: (UniqueValue) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""

  private var filteredValues: [UniqueValue] {
    guard !searchText.isEmpty else { return values }
    return values.filter { $0.displayValue.localizedCaseInsensitiveContains(searchText) }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text(columnName)
            .font(.title2.weight(.semibold))
          Text(
            "\(values.count.formatted()) unique values across \(rowCount.formatted()) visible rows"
          )
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding()

      TextField("Search values", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .padding(.horizontal)
        .padding(.bottom, 12)

      Divider()

      if filteredValues.isEmpty {
        ContentUnavailableView.search(text: searchText)
      } else {
        List(filteredValues) { item in
          HStack(spacing: 12) {
            Text(item.displayValue)
              .foregroundStyle(item.value == nil ? .secondary : .primary)
              .textSelection(.enabled)
              .lineLimit(3)
            Spacer()
            Text(item.count.formatted())
              .foregroundStyle(.secondary)
              .monospacedDigit()
            Button("Filter") {
              applyFilter(item)
              dismiss()
            }
            .buttonStyle(.borderless)
          }
          .padding(.vertical, 3)
        }
        .alternatingRowBackgrounds()
      }
    }
    .frame(minWidth: 560, minHeight: 520)
  }
}
