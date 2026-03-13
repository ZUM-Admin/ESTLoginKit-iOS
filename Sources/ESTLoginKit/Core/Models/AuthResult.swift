//
//  AuthResult.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/12/26.
//

import Foundation

public struct AuthResult {
  public let authorizeToken: String
  public let refreshToken: String
  public let ci: String
  public let email: String

  public init(
    authorizeToken: String,
    refreshToken: String = "",
    ci: String = "",
    email: String = ""
  ) {
    self.authorizeToken = authorizeToken
    self.refreshToken = refreshToken
    self.ci = ci
    self.email = email
  }
}
