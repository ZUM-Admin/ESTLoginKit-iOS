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
        // GoogleSignIn 9.0.0 + 모든 의존성(FBLPromises, GoogleUtilities 등)을
        // 하나의 static XCFramework로 머지하여 소비자 프로젝트의 전이 의존성 충돌 방지
        .binaryTarget(
            name: "GoogleSignIn",
            path: "Frameworks/GoogleSignIn.xcframework"
        ),
        .target(
            name: "ESTLoginKit",
            dependencies: [
              // KAKAO
              .product(name: "KakaoSDKCommon", package: "kakao-ios-sdk"),
              .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
              .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),

              // NAVER
              .product(name: "NidThirdPartyLogin", package: "naveridlogin-sdk-ios-swift"),

              // Google (binary target - 전이 의존성 없음)
              "GoogleSignIn"
            ]
        ),
        .testTarget(
            name: "ESTLoginKitTests",
            dependencies: ["ESTLoginKit"]
        ),
    ]
)
