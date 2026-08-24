// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "file_picker", path: "../.packages/file_picker-10.3.10"),
        .package(name: "file_selector_macos", path: "../.packages/file_selector_macos-0.9.5"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-4.12.1"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-16.4.3"),
        .package(name: "flutter_blue_plus_darwin", path: "../.packages/flutter_blue_plus_darwin-7.0.3"),
        .package(name: "flutter_secure_storage_darwin", path: "../.packages/flutter_secure_storage_darwin-0.2.0"),
        .package(name: "geolocator_apple", path: "../.packages/geolocator_apple-2.3.13"),
        .package(name: "mobile_scanner", path: "../.packages/mobile_scanner-7.2.0"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-9.0.1"),
        .package(name: "path_provider_foundation", path: "../.packages/path_provider_foundation-2.5.1"),
        .package(name: "share_plus", path: "../.packages/share_plus-12.0.1"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "url_launcher_macos", path: "../.packages/url_launcher_macos-3.2.5"),
        .package(name: "wakelock_plus", path: "../.packages/wakelock_plus-1.5.1"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "file-selector-macos", package: "file_selector_macos"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "flutter-blue-plus-darwin", package: "flutter_blue_plus_darwin"),
                .product(name: "flutter-secure-storage-darwin", package: "flutter_secure_storage_darwin"),
                .product(name: "geolocator-apple", package: "geolocator_apple"),
                .product(name: "mobile-scanner", package: "mobile_scanner"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "url-launcher-macos", package: "url_launcher_macos"),
                .product(name: "wakelock-plus", package: "wakelock_plus"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
