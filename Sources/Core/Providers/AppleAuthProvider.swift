//
//  AppleAuthProvider.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/3/26.
//

import UIKit
import AuthenticationServices

final class AppleAuthProvider: NSObject, AuthProvider {

  private var continuation: CheckedContinuation<AuthResult, Error>?

  @MainActor
  func login() async throws -> AuthResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      let request = ASAuthorizationAppleIDProvider().createRequest()
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }
}

extension AppleAuthProvider: ASAuthorizationControllerDelegate {

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard
      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let tokenData = credential.identityToken,
      let identityToken = String(data: tokenData, encoding: .utf8)
    else {
      continuation?.resume(throwing: AuthError.unknown(nil))
      return
    }
    continuation?.resume(returning: AuthResult(
      authorizeToken: identityToken,
      email: credential.email ?? ""
    ))
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    continuation?.resume(throwing: error)
  }
}

extension AppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {

  @MainActor
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first(where: { $0.isKeyWindow })
    else {
      return UIWindow()
    }
    return window
  }
}
