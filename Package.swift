// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TimeToMeet",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MeetingCore", targets: ["MeetingCore"]),
        .executable(name: "TimeToMeet", targets: ["TimeToMeet"])
    ],
    targets: [
        .target(
            name: "MeetingCore",
            path: "Sources/MeetingCore"
        ),
        .executableTarget(
            name: "TimeToMeet",
            dependencies: ["MeetingCore"],
            path: "Sources/TimeToMeet"
        ),
        .testTarget(
            name: "MeetingCoreTests",
            dependencies: ["MeetingCore"],
            path: "Tests/MeetingCoreTests"
        )
    ]
)
