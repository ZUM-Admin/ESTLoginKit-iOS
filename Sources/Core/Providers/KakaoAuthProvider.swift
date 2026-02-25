//
//  KakaoAuthProvider.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

import KakaoSDKUser
import KakaoSDKAuth
import KakaoSDKCommon

final class KakaoAuthProvider: AuthProvider {
  
  @MainActor
  func login() async throws -> String {
    // 1. 카카오톡 실행 가능 여부 확인
    if UserApi.isKakaoTalkLoginAvailable() {
      return try await loginWithKakaoTalk()
    } else {
      // 2. 카카오톡 미설치 시 웹 브라우저로 로그인
      return try await loginWithKakaoAccount()
    }
  }
  
  @MainActor
  private func loginWithKakaoTalk() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      UserApi.shared.loginWithKakaoTalk { (oauthToken, error) in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = oauthToken {
          continuation.resume(returning: token.accessToken)
        }
      }
    }
  }
  
  @MainActor
  private func loginWithKakaoAccount() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      UserApi.shared.loginWithKakaoAccount { (oauthToken, error) in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = oauthToken {
          continuation.resume(returning: token.accessToken)
        }
      }
    }
  }
}
