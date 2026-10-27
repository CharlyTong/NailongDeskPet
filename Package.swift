// swift-tools-version: 6.0
// Package.swift = SPM 项目的"总装清单"，类比 Python 的 pyproject.toml
import PackageDescription

let package = Package(
    name: "DeskPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeskPet",
            path: "Sources/DeskPet",
            resources: [
                // .copy：把目录原样打进 bundle（保留 Sprites/ 子目录）
                .copy("Resources/Sprites"),
                // .process：把 JSON 平铺到 bundle 根目录
                .process("Resources/SpriteConfig.json")
            ]
        )
    ],
    // v5 语言模式：用 6.3 编译器但不开启严格并发检查（对初学者更友好）
    swiftLanguageModes: [.v5]
)
