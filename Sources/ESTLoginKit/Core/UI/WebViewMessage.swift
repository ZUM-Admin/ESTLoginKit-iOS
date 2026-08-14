//
//  WebViewMessage.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

enum WebViewMessage: String, CaseIterable {
  case requestSnsLogin
  case requestLogout
  case onLoginComplete
  case onPasswordChanged
  case onAccountDeleted

  /// 웹이 심는 분석 이벤트. 다른 메시지와 달리 SDK가 해석하지 않고 호스트로 흘려보내기만 한다.
  /// 이벤트 종류는 페이로드의 `event_key`로 구분한다 — 이벤트가 늘어도 SDK는 그대로다.
  case trackEvent

  func decode(from data: Data) -> Decodable? {
    switch self {
    case .requestSnsLogin:
      return try? JSONDecoder.instance.decode(SNSLoginRequestPayload.self, from: data)
    case .requestLogout, .onLoginComplete, .onPasswordChanged, .onAccountDeleted:
      // 페이로드 없음 — 인자 없는 동작 요청이거나 관찰/통지용
      return nil
    case .trackEvent:
      // 스키마가 없어 Decodable로 고정할 수 없다. `WebEventParser`가 직접 처리한다.
      return nil
    }
  }
}
