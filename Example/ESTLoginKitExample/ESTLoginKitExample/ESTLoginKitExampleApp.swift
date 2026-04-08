//
//  ESTLoginKitExampleApp.swift
//  ESTLoginKitExample
//

import SwiftUI

import ESTLoginKit

@main
struct ESTLoginKitExampleApp: App {

  init() {
    Task {
      let config = ESTLoginConfiguration.Builder(clientId: "8941192")
        .useKakao(KakaoConfiguration(appKey: "d3a19dde0b860aaaf4aec55e2a12db02"))
//        .useNaver(NaverConfiguration(
//          appName: "앱이름",
//          clientID: "YOUR_NAVER_CLIENT_ID",
//          clientSecret: "YOUR_NAVER_CLIENT_SECRET",
//          urlScheme: "YOUR_NAVER_URL_SCHEME"
//        ))
        .build()

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
