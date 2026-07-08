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
  /// 값이 있을 때만 payload에 "email" 키가 포함된다. 빈 문자열/공백은 nil 취급하여 키 자체를 생략.
  /// (Encodable 합성 구현이 Optional을 encodeIfPresent로 인코딩하므로 nil이면 키가 빠진다.)
  let email: String?

  init(
    provider: String,
    authorizeToken: String,
    refreshToken: String,
    ci: String,
    email: String
  ) {
    self.provider = provider
    self.authorizeToken = authorizeToken
    self.refreshToken = refreshToken
    self.ci = ci
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    self.email = trimmed.isEmpty ? nil : trimmed
  }
}
