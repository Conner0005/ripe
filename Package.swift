// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"]),
    ],
    targets: [
        .target(name: "PomodoroCore"),
        .executableTarget(name: "Pomodoro", dependencies: ["PomodoroCore"]),
        .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"]),
    ]
)
