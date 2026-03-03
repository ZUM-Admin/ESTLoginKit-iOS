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
  func login() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      NidOAuth.shared.requestLogin { result in
        switch result {
        case .success(let loginResult):
          continuation.resume(returning: loginResult.accessToken.tokenString)
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
