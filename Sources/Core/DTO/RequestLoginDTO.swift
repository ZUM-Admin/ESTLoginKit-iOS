//
//  File.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/26/26.
//

import Foundation

struct RequestLoginDTO: Decodable {
  let platform: Platform
}

extension RequestLoginDTO {
  enum Platform: String, Decodable {
    case kakao, naver, google, apple
  }
}
