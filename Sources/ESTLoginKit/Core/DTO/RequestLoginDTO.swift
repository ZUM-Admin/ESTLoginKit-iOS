//
//  File.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/26/26.
//

import Foundation

struct RequestLoginDTO: Decodable {
  let type: String
  let provider: Provider
}

extension RequestLoginDTO {
  enum Provider: String, Decodable {
    case kakao, naver
  }
}
