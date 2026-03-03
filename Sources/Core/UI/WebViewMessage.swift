//
//  WebViewMessage.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

enum WebViewMessage: String, CaseIterable {
  case requestLogin
  
  func decode(from data: Data) -> Decodable? {
    switch self {
    case .requestLogin:
      return try? JSONDecoder.instance.decode(RequestLoginDTO.self, from: data)
    }
  }
}
