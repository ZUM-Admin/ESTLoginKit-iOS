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
      let config = ESTLoginConfiguration.Builder()
        .useKakao(KakaoConfiguration(appKey: "YOUR_KAKAO_APP_KEY"))
        .useNaver(NaverConfiguration(
          appName: "앱이름",
          clientID: "YOUR_NAVER_CLIENT_ID",
          clientSecret: "YOUR_NAVER_CLIENT_SECRET",
          urlScheme: "YOUR_NAVER_URL_SCHEME"
        ))
        .useGoogle()   // Info.plist의 GIDClientID 자동 참조
        .useApple()    // Xcode Capability에서 Sign in with Apple 활성화 필요
        .build()

      await ESTLoginManager.shared.initialize(with: config)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onOpenURL { url in
          // 카카오 / 네이버 / 구글 OAuth 콜백 URL 처리
          Task { @MainActor in
            _ = await ESTLoginManager.shared.handle(url)
          }
        }
    }
  }
}
