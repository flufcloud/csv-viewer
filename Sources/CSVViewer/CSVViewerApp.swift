import SwiftUI

@main
struct CSVViewerApp: App {
  @StateObject private var model = ViewerModel()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        .frame(minWidth: 760, minHeight: 480)
        .onOpenURL { model.open($0) }
    }
    .defaultSize(width: 1180, height: 760)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open CSV…") {
          model.showOpenPanel()
        }
        .keyboardShortcut("o")
      }
    }
  }
}
