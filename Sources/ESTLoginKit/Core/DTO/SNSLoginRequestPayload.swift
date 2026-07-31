//
//  SNSLoginRequestPayload.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/26/26.
//

import Foundation

struct SNSLoginRequestPayload: Decodable {
  let type: String
  let provider: Provider
}

extension SNSLoginRequestPayload {
  enum Provider: String, Decodable {
    case kakao, naver
  }
}
