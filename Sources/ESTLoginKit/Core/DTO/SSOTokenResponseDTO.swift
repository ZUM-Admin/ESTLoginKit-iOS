//
//  SSOTokenResponseDTO.swift
//  ESTLoginKit
//
//  `GET {apiBaseURL}/auth/sso/sso-token` 응답.
//

import Foundation

/// `{ "result": { "ssoToken": "..." }, "message": "" }`
struct SSOTokenResponseDTO: Decodable {
  let result: Result

  struct Result: Decodable {
    let ssoToken: String
  }
}
