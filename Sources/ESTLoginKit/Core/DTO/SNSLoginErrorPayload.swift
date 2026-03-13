//
//  SNSLoginErrorPayload.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/10/26.
//

import Foundation

struct SNSLoginErrorPayload: Encodable {
  let code: String
  let message: String
  let provider: String
}

