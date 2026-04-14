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
      let config = ESTLoginConfiguration.Builder(clientId: "YOUR_CLIENT_ID")
        // 개발 환경용 베이스 URL 오버라이드 (미지정 시 기본값 https://estoneid.com 사용)
        // .useBaseURL("https://test.estoneid.com")
        .useKakao(KakaoConfiguration(appKey: "KAKAO_SDK_KEY"))
        .useNaver(NaverConfiguration(
          appName: "YOUR_APP_NAME",
          clientID: "NAVER_CLIENT_ID",
          clientSecret: "NAVER_CLIENT_SECRET",
          urlScheme: "NAVER_URL_SCHEME"
        ))
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
