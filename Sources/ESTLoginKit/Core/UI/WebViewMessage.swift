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

  func decode(from data: Data) -> Decodable? {
    switch self {
    case .requestSnsLogin:
      return try? JSONDecoder.instance.decode(SNSLoginRequestPayload.self, from: data)
    case .requestLogout, .onLoginComplete, .onPasswordChanged, .onAccountDeleted:
      // 페이로드 없음 — 인자 없는 동작 요청이거나 관찰/통지용
      return nil
    }
  }
}
