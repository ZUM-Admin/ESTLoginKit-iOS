//
//  WebViewMessage.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

enum WebViewMessage: String, CaseIterable {
  case requestSnsLogin
  case onLoginComplete
  case onPasswordChanged
  case onAccountDeleted
  /// 본인인증 완료 통지. 로그인용 `onLoginComplete`와 분리된 별도 메서드다.
  case onVerificationComplete

  func decode(from data: Data) -> Decodable? {
    switch self {
    case .requestSnsLogin:
      return try? JSONDecoder.instance.decode(RequestLoginDTO.self, from: data)
    case .onVerificationComplete:
      return try? JSONDecoder.instance.decode(VerificationCompletePayload.self, from: data)
    case .onLoginComplete, .onPasswordChanged, .onAccountDeleted:
      // 현재는 관찰/통지용 — 별도 디코딩 불필요
      return nil
    }
  }
}
