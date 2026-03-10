//
//  SNSLoginSuccessPayload.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/10/26.
//

import Foundation

struct SNSLoginSuccessPayload: Encodable {
  let provider: String
  let authorizeToken: String
  let refreshToken: String
  let ci: String
  let email: String
}
