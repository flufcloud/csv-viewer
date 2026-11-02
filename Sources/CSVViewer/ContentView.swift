import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject var model: ViewerModel
  @AppStorage("appTheme") private var appTheme: AppTheme = .system
  @AppStorage("renderMarkdown") private var renderMarkdown = true
  @State private var isDropTargeted = false
  @State private var isShowingUniqueValues = false

  var body: some View {
    Group {
      if model.headers.isEmpty {
        emptyState
      } else {
        viewer
      }
    }
    .overlay {
      if model.isLoading {
        ZStack {
          Color.black.opacity(0.12)
          ProgressView("Opening CSV…")
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
    .alert("Could not open file", isPresented: errorBinding) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "Unknown error")
    }
    .sheet(isPresented: $isShowingUniqueValues) {
      UniqueValuesView(
        columnName: model.headers[model.uniqueValueColumn],
        rowCount: model.visibleRows.count,
        values: model.uniqueValues,
        applyFilter: model.filterForUniqueValue
      )
    }
    .dropDestination(for: URL.self) { urls, _ in
      let supportedExtensions = ["csv", "tsv", "txt"]
      guard let url = urls.first, supportedExtensions.contains(url.pathExtension.lowercased())
      else {
        return false
      }
      model.open(url)
      return true
    } isTargeted: {
      isDropTargeted = $0
    }
    .preferredColorScheme(appTheme.colorScheme)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        displayMenu
      }
    }
  }

  private var viewer: some View {
    VStack(spacing: 0) {
      controls
      Divider()
      CSVTable(model: model, renderMarkdown: renderMarkdown) { column in
        model.selectUniqueValueColumn(column)
        isShowingUniqueValues = true
      }
      Divider()
      statusBar
    }
    .navigationTitle(model.fileURL?.lastPathComponent ?? "CSV Viewer")
  }

  private var displayMenu: some View {
    Menu {
      Picker("Theme", selection: $appTheme) {
        ForEach(AppTheme.allCases) { theme in
          Text(theme.title).tag(theme)
        }
      }
      Divider()
      Toggle("Render Markdown", isOn: $renderMarkdown)
    } label: {
      Label("Display", systemImage: "paintbrush")
    }
    .help("Change the theme and Markdown rendering")
  }

  private var controls: some View {
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        Button {
          model.showOpenPanel()
        } label: {
          Label("Open", systemImage: "folder")
        }

        Divider().frame(height: 22)

        Button {
          model.addFilter()
        } label: {
          Label("Add Filter", systemImage: "plus")
        }

        if !model.filters.isEmpty {
          Button("Clear Filters", action: model.clearFilters)
          Text("All \(model.activeFilterCount) active filters must match")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if !model.selectedColumns.isEmpty {
          Divider().frame(height: 22)
          Text("\(model.selectedColumns.count) selected")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Hide Selected", action: model.hideSelectedColumns)
            .disabled(!model.canHideSelectedColumns)
          Button(action: model.clearColumnSelection) {
            Image(systemName: "xmark")
          }
          .buttonStyle(.plain)
          .help("Clear column selection")
        }

        Spacer()
        valuesMenu
        columnMenu

        if !model.hiddenRows.isEmpty {
          Button("Show \(model.hiddenRows.count) hidden rows") {
            model.showAllRows()
          }
        }
      }

      if !model.filters.isEmpty {
        ScrollView(.vertical) {
          LazyVStack(spacing: 6) {
            ForEach($model.filters) { $filter in
              FilterRuleEditor(
                filter: $filter,
                headers: model.headers,
                remove: { model.removeFilter(filter.id) }
              )
            }
          }
        }
        .frame(maxHeight: 240)
      }
    }
    .padding(10)
    .background(.bar)
  }

  private var valuesMenu: some View {
    Menu {
      ForEach(model.headers.indices, id: \.self) { index in
        Button(model.headers[index]) {
          model.selectUniqueValueColumn(index)
          isShowingUniqueValues = true
        }
      }
    } label: {
      Label("Values", systemImage: "list.number")
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private var columnMenu: some View {
    Menu {
      if !model.selectedColumns.isEmpty {
        Button("Hide selected columns", action: model.hideSelectedColumns)
          .disabled(!model.canHideSelectedColumns)
        Button("Clear column selection", action: model.clearColumnSelection)
        Divider()
      }
      ForEach(model.headers.indices, id: \.self) { index in
        Button {
          model.toggleColumn(index)
        } label: {
          Label(
            model.headers[index],
            systemImage: model.hiddenColumns.contains(index) ? "square" : "checkmark.square"
          )
        }
      }
      Divider()
      Button("Show all columns", action: model.showAllColumns)
        .disabled(model.hiddenColumns.isEmpty)
    } label: {
      Label("Columns", systemImage: "rectangle.3.group")
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private var statusBar: some View {
    HStack {
      let shown = model.visibleRows.count
      Text("\(shown.formatted()) of \(model.totalRowCount.formatted()) rows")
      Text("•")
        .foregroundStyle(.tertiary)
      Text("\(model.visibleColumnIndices.count) of \(model.headers.count) columns")
      Text("•")
        .foregroundStyle(.tertiary)
      Text(delimiterName)
      if let filterError = model.filterError {
        Spacer()
        Label(filterError, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
      } else if let recoveryNotice = model.recoveryNotice {
        Spacer()
        Label(recoveryNotice, systemImage: "wrench.and.screwdriver.fill")
          .foregroundStyle(.orange)
      } else {
        Spacer()
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .frame(height: 30)
    .background(.bar)
  }

  private var delimiterName: String {
    switch model.delimiter {
    case "\t": "Tab separated"
    case ";": "Semicolon separated"
    case "|": "Pipe separated"
    default: "Comma separated"
    }
  }

  private var emptyState: some View {
    VStack(spacing: 18) {
      Image(systemName: "tablecells")
        .font(.system(size: 58, weight: .light))
        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
      VStack(spacing: 6) {
        Text(isDropTargeted ? "Drop to open" : "Open a CSV file")
          .font(.title2.weight(.semibold))
        Text(
          "Values wrap inside the window. Filter, sort, and hide rows or columns without changing the file."
        )
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
      }
      Button("Choose File…") {
        model.showOpenPanel()
      }
      .controlSize(.large)
      .keyboardShortcut(.defaultAction)
      Text("You can also drop a .csv file here")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { model.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          model.clearError()
        }
      }
    )
  }
}

private struct FilterRuleEditor: View {
  @Binding var filter: FilterRule
  let headers: [String]
  let remove: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 10) {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .foregroundStyle(.secondary)

        Picker("Column", selection: $filter.column) {
          ForEach(headers.indices, id: \.self) { index in
            Text(headers[index]).tag(index)
          }
        }
        .labelsHidden()
        .frame(maxWidth: 190)

        Picker("Operator", selection: $filter.operation) {
          ForEach(FilterOperator.allCases) { operation in
            Text(operation.rawValue).tag(operation)
          }
        }
        .labelsHidden()
        .frame(width: 190)

        if !filter.operation.isJSONFilter {
          valueControl
        }

        Spacer()

        if let error = filter.error {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .help(error)
        }

        Button(action: remove) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .help("Remove filter")
      }

      if filter.operation.isJSONFilter {
        HStack(spacing: 10) {
          Color.clear.frame(width: 16)
          Label("JSON", systemImage: "curlybraces")
            .foregroundStyle(.secondary)
          TextField("Field path, e.g. classification", text: $filter.jsonPath)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 280)
            .help("Use dot paths and array indexes, such as metadata.label or items[0].type")
          valueControl
          Spacer()
        }
      }
    }
    .padding(8)
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var valueControl: some View {
    if filter.operation.needsValue {
      TextField("Filter value", text: $filter.filterText)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 260)
    } else {
      Text("No value required")
        .foregroundStyle(.secondary)
        .frame(maxWidth: 260, alignment: .leading)
    }
  }
}

private struct CSVTable: View {
  @ObservedObject var model: ViewerModel
  let renderMarkdown: Bool
  let showUniqueValues: (Int) -> Void
  @State private var columnWeights: [Int: Double] = [:]

  var body: some View {
    GeometryReader { geometry in
      let indices = model.visibleColumnIndices
      let utilityWidth = 42.0
      let availableWidth = max(
        1, Double(geometry.size.width) - utilityWidth - Double(indices.count))
      let widths = ColumnLayout.widths(
        indices: indices, availableWidth: availableWidth, weights: columnWeights)

      ScrollView(.vertical) {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
          Section {
            ForEach(model.visibleRows) { row in
              dataRow(row, indices: indices, widths: widths)
            }
          } header: {
            headerRow(indices: indices, widths: widths, availableWidth: availableWidth)
          }
        }
      }
      .background(Color(nsColor: .textBackgroundColor))
    }
    .onChange(of: model.fileURL) {
      columnWeights.removeAll()
    }
  }

  private func headerRow(
    indices: [Int], widths: [Int: Double], availableWidth: Double
  ) -> some View {
    HStack(alignment: .top, spacing: 0) {
      Color.clear.frame(width: 42)
      ForEach(Array(indices.enumerated()), id: \.element) { position, index in
        Button {
          model.selectColumn(index, extending: NSEvent.modifierFlags.contains(.command))
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(model.headers[index])
              .fontWeight(.semibold)
              .multilineTextAlignment(.leading)
              .lineLimit(3)
            if model.sortColumn == index {
              Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
                .font(.caption2)
            }
            Spacer(minLength: 0)
          }
          .padding(8)
          .frame(width: widths[index] ?? 1, alignment: .leading)
          .contentShape(Rectangle())
          .background(
            model.selectedColumns.contains(index) ? Color.accentColor.opacity(0.18) : Color.clear
          )
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button("Sort ascending") { model.setSort(column: index, ascending: true) }
          Button("Sort descending") { model.setSort(column: index, ascending: false) }
          if model.sortColumn == index {
            Button("Clear sort") { model.clearSort() }
          }
          Divider()
          Button("Show unique values") { showUniqueValues(index) }
          Button("Hide column") { model.toggleColumn(index) }
          if model.selectedColumns.contains(index) {
            Button("Hide selected columns", action: model.hideSelectedColumns)
              .disabled(!model.canHideSelectedColumns)
          }
        }
        .overlay(alignment: .trailing) {
          if position < indices.count - 1 {
            ColumnResizeHandle { delta in
              columnWeights = ColumnLayout.resize(
                indices: indices,
                availableWidth: availableWidth,
                weights: columnWeights,
                left: index,
                right: indices[position + 1],
                delta: delta
              )
            }
            .offset(x: 5)
          }
        }
        Divider()
      }
    }
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
  }

  private func dataRow(_ row: CSVRow, indices: [Int], widths: [Int: Double]) -> some View {
    HStack(alignment: .top, spacing: 0) {
      Button {
        model.hideRow(row.id)
      } label: {
        Image(systemName: "eye.slash")
          .foregroundStyle(.secondary)
          .frame(width: 42)
          .padding(.vertical, 9)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Hide row \(row.id + 1)")

      ForEach(indices, id: \.self) { index in
        Text(
          renderMarkdown
            ? MarkdownRenderer.render(row.values[index])
            : AttributedString(row.values[index])
        )
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
        .frame(width: widths[index] ?? 1, alignment: .topLeading)
        .background(
          model.selectedColumns.contains(index) ? Color.accentColor.opacity(0.055) : Color.clear
        )
        .contextMenu {
          Button("Filter to this value") {
            model.filterForValue(column: index, value: row.values[index])
          }
          Button("Show unique values") { showUniqueValues(index) }
          Button("Hide column") { model.toggleColumn(index) }
          Divider()
          Button("Hide row") { model.hideRow(row.id) }
        }
        Divider()
      }
    }
    .background(row.id.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.025))
    .overlay(alignment: .bottom) { Divider() }
  }
}

private struct ColumnResizeHandle: View {
  let resize: (Double) -> Void
  @State private var previousTranslation = 0.0

  var body: some View {
    Color.clear
      .frame(width: 10)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .onHover { hovering in
        if hovering {
          NSCursor.resizeLeftRight.push()
        } else {
          NSCursor.pop()
        }
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let translation = Double(value.translation.width)
            resize(translation - previousTranslation)
            previousTranslation = translation
          }
          .onEnded { _ in
            previousTranslation = 0
          }
      )
      .help("Drag to resize columns")
  }
}
