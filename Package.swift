// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "MagicStackBar",
  platforms: [.macOS(.v14)],
  targets: [
    .executableTarget(
      name: "MagicStackBar",
      path: "Sources/MagicStackBar"
    )
  ]
)
