# CSV Viewer

A lightweight native macOS viewer for CSV and other delimited text files.

## Features

- Opens files from the app, drag and drop, or Finder's **Open With** menu
- Wraps cell text within the window without horizontal scrolling
- Resizes adjacent columns by dragging a header divider
- Filters a selected column using text, equality, prefix, suffix, or regular expressions
- Filters null and non-null values; empty cells and common markers such as `NULL`, `N/A`, and `NaN` count as null
- Shows unique values and occurrence counts for any column, with search and one-click filtering
- Filters fields inside JSON cells using dot paths and array indexes, with typed equality, inequality, contains, and exists operators
- Composes multiple text, null, regex, and JSON rules; all active filters must match
- Renders inline Markdown in cells, including bold, emphasis, links, and inline code
- Offers persistent System, Classic Light, and Night appearance settings
- Sorts text or numeric columns from each header's context menu
- Selects one column by clicking its header or multiple columns with Command-click
- Hides individual rows, columns, or all selected columns without modifying the source file
- Handles quoted commas, escaped quotes, multiline fields, and UTF-8 or Latin-1 text
- Recovers a partial final row when a quoted field is truncated at the end of a file
- Detects comma, tab, semicolon, and pipe delimiters

## Run during development

```sh
swift run CSVViewer
```

## Build the app

```sh
./scripts/build-app.sh
open "dist/CSV Viewer.app"
```

## Add CSV Viewer to Finder's Open With menu

```sh
./scripts/install-app.sh
```

This installs the app to `~/Applications`, registers its CSV document types with macOS, and leaves the project files untouched. Right-click a `.csv` file and choose **Open With → CSV Viewer**. To make it the default, choose **Get Info**, select CSV Viewer under **Open with**, then click **Change All**.

To install an app that has already been built without compiling it again, run `./scripts/install-app.sh --use-built`.

The app only reads files. Filtering, sorting, and hiding data do not change the source CSV.

## Filter fields inside JSON cells

Select the CSV column, then choose a JSON filter operator. Enter the field path and value in the additional controls. For example:

- Column: `meaningful_information`
- Operator: `JSON field equals`
- JSON path: `classification`
- Value: `true`

Nested objects use dot paths such as `metadata.label`. Arrays use indexes such as `items[0].type`. A leading `$` is optional, so `$.metadata.label` also works. Rows with malformed JSON or a missing path do not match; `JSON field exists` does match a field whose JSON value is `null`.

Use **Add Filter** to compose rules across columns. Each complete rule is applied with AND semantics. Remove one rule with its × button or use **Clear Filters** to reset the full pipeline. Filters created from a cell's context menu or the unique-values window are added to the current rules.

## Display settings

Use the **Display** menu in the window toolbar to switch between System, Classic Light, and Night themes. The same menu can turn Markdown rendering on or off. Both choices persist across launches.
