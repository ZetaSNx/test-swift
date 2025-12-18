// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ProyectoSwiftJhonMaroLozano",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // ¡ESTA LÍNEA ES OBLIGATORIA AHORA!
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", from: "1.3.1"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                // ¡ESTA TAMBIÉN!
                .product(name: "MongoSwift", package: "mongo-swift-driver"),
            ],
            path: "Sources/App"
        )
    ]
)