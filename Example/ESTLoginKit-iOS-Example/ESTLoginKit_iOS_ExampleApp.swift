//
//  ESTLoginKit_iOS_ExampleApp.swift
//  ESTLoginKit-iOS-Example
//
//  Created by ESTAID on 7/14/26.
//

import SwiftUI

import ESTLoginKit

@main
struct ESTLoginKit_iOS_ExampleApp: App {

  init() {
    // 모든 시크릿은 Config.xcconfig → Info.plist → ExampleConfig 경로로 주입된다. (소스에 하드코딩 없음)
    let kakaoAppKey = ExampleConfig.kakaoAppKey
    // customScheme = kakao{앱키}-{번들ID}. Info.plist에도 같은 스킴이 등록돼 있다.
    let bundleId = Bundle.main.bundleIdentifier ?? ""

    let config = ESTLoginConfiguration.Builder(clientId: ExampleConfig.clientID)
      .useEnvironment(ExampleConfig.environment)
      .useKakao(KakaoConfiguration(
        appKey: kakaoAppKey,
        customScheme: "kakao\(kakaoAppKey)-\(bundleId)"
      ))
      .useNaver(NaverConfiguration(
        appName: ExampleConfig.naverAppName,
        clientID: ExampleConfig.naverClientID,
        clientSecret: ExampleConfig.naverClientSecret,
        urlScheme: ExampleConfig.naverURLScheme
      ))
      .build()

    Task {
      await ESTLoginManager.shared.initialize(with: config)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onOpenURL { url in
          // 카카오 / 네이버 OAuth 콜백 URL 처리
          Task { @MainActor in
            _ = ESTLoginManager.shared.handle(url)
          }
        }
    }
  }
}
