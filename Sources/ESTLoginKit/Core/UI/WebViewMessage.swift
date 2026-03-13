//
//  WebViewMessage.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

enum WebViewMessage: String, CaseIterable {
  case requestSnsLogin

  func decode(from data: Data) -> Decodable? {
    switch self {
    case .requestSnsLogin:
      return try? JSONDecoder.instance.decode(RequestLoginDTO.self, from: data)
    }
  }
}
