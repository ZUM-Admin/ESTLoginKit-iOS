//
//  NaverAuthProvider.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/27/26.
//

import Foundation

import NidThirdPartyLogin

final class NaverAuthProvider: NSObject, AuthProvider {
  
  @MainActor
  func login() async throws -> AuthResult {
    return try await withCheckedThrowingContinuation { continuation in
      NidOAuth.shared.requestLogin { result in
        switch result {
        case .success(let loginResult):
          continuation.resume(returning: AuthResult(
            authorizeToken: loginResult.accessToken.tokenString,
            refreshToken: loginResult.refreshToken.tokenString
          ))
        case .failure(let error):
          if case NidError.clientError(.canceledByUser) = error {
            continuation.resume(throwing: AuthError.cancelled)
          } else {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
}
