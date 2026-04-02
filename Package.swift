// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ESTLoginKit",
    platforms: [.iOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ESTLoginKit",
            targets: ["ESTLoginKit"]
        ),
    ],
    dependencies: [
      .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.27.2"),
      .package(url: "https://github.com/naver/naveridlogin-sdk-ios-swift", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "ESTLoginKit",
            dependencies: [
              // KAKAO
              .product(name: "KakaoSDKCommon", package: "kakao-ios-sdk"),
              .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
              .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),

              // NAVER
              .product(name: "NidThirdPartyLogin", package: "naveridlogin-sdk-ios-swift"),
            ]
        ),
        .testTarget(
            name: "ESTLoginKitTests",
            dependencies: ["ESTLoginKit"]
        ),
    ]
)
