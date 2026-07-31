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

  func decode(from data: Data) -> Decodable? {
    switch self {
    case .requestSnsLogin:
      return try? JSONDecoder.instance.decode(SNSLoginRequestPayload.self, from: data)
    case .onLoginComplete, .onPasswordChanged, .onAccountDeleted:
      // 현재는 관찰/통지용 — 별도 디코딩 불필요
      return nil
    }
  }
}
