// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CSVViewer",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "CSVViewer", targets: ["CSVViewer"])
  ],
  targets: [
    .executableTarget(name: "CSVViewer"),
    .testTarget(name: "CSVViewerTests", dependencies: ["CSVViewer"]),
  ]
)
