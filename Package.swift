// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TimeToMeet",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TimeToMeet",
            path: "Sources/TimeToMeet"
        )
    ]
)
