//
//  GoogleAuthProvider.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/3/26.
//

import UIKit

import GoogleSignIn

final class GoogleAuthProvider: AuthProvider {

  @MainActor
  func login() async throws -> String {
    guard
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      throw AuthError.unknown(nil)
    }

    return try await withCheckedThrowingContinuation { continuation in
      GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let idToken = result?.user.idToken?.tokenString else {
          continuation.resume(throwing: AuthError.unknown(nil))
          return
        }
        continuation.resume(returning: idToken)
      }
    }
  }
}
