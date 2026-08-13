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
  func login() async throws -> AuthResult {
    // 1. 카카오톡 실행 가능 여부 확인
    let tokens: (access: String, refresh: String)
    if UserApi.isKakaoTalkLoginAvailable() {
      tokens = try await loginWithKakaoTalk()
    } else {
      // 2. 카카오톡 미설치 시 웹 브라우저로 로그인
      tokens = try await loginWithKakaoAccount()
    }

    // 3. 토큰 획득 성공 직후, 콜백 발화 전에 프로필 API 1회 호출해 email 조회.
    //    조회 실패/미동의/빈 값이면 email 없이 진행 (로그인 실패로 만들지 않음).
    let email = await fetchEmail()

    return AuthResult(
      authorizeToken: tokens.access,
      refreshToken: tokens.refresh,
      email: email
    )
  }

  @MainActor
  private func loginWithKakaoTalk() async throws -> (access: String, refresh: String) {
    return try await withCheckedThrowingContinuation { continuation in
      UserApi.shared.loginWithKakaoTalk { (oauthToken, error) in
        if let error = error {
          continuation.resume(throwing: Self.mapError(error))
        } else if let token = oauthToken {
          continuation.resume(returning: (token.accessToken, token.refreshToken))
        }
      }
    }
  }

  /// 카카오계정 로그인 — 항상 계정 선택 화면을 띄운다.
  ///
  /// 이 경로는 `ASWebAuthenticationSession`으로 열려 사파리 쿠키를 그대로 쓰는데, 카카오계정
  /// 로그인 세션은 앱 로그아웃으로 지워지지 않는다(앱이 접근할 수 있는 저장소가 아니다).
  /// 그래서 `prompts` 없이 호출하면 남아있는 세션으로 자동 통과해버려 **다른 계정으로 로그인할
  /// 방법이 없다.** 네이버가 겪었던 것과 같은 문제이며(`NaverAuthProvider`의 `reauthenticate`),
  /// 해법도 같다 — 지우는 대신 로그인 시점에 저장된 세션을 쓰지 않게 만든다.
  ///
  /// `.Login`(매번 재인증 강제)이 아니라 `.SelectAccount`를 쓴다. 계정 선택·추가만 시키고
  /// 이미 로그인된 계정은 다시 인증하지 않는다. 저장된 세션이 없거나 하나면 선택 목록 대신
  /// 로그인 폼이 뜬다 — 정상 동작이다.
  ///
  /// **카카오톡 앱 경로에는 적용되지 않는다** — `prompts`는 카카오계정 로그인에만 있는 옵션이다.
  /// 카카오톡이 설치돼 있으면 그쪽이 우선이고, 카카오톡은 기기당 한 계정이라 계정 전환은
  /// 카카오톡에서 해야 한다.
  @MainActor
  private func loginWithKakaoAccount() async throws -> (access: String, refresh: String) {
    return try await withCheckedThrowingContinuation { continuation in
      UserApi.shared.loginWithKakaoAccount(prompts: [.SelectAccount]) { (oauthToken, error) in
        if let error = error {
          continuation.resume(throwing: Self.mapError(error))
        } else if let token = oauthToken {
          continuation.resume(returning: (token.accessToken, token.refreshToken))
        }
      }
    }
  }

  /// 카카오 계정에서 email 조회. 실패/미동의/빈 값이면 "" 반환 (절대 throw하지 않음).
  /// 참고: Kakao Developers 콘솔에서 account_email 동의항목이 활성화되어 있어야 하며,
  /// 사용자가 동의를 거부하면 nil이 내려온다.
  @MainActor
  private func fetchEmail() async -> String {
    return await withCheckedContinuation { continuation in
      UserApi.shared.me { (user, _) in
        continuation.resume(returning: user?.kakaoAccount?.email ?? "")
      }
    }
  }

  private static func mapError(_ error: Error) -> Error {
    if case SdkError.ClientFailed(reason: .Cancelled, _) = error {
      return AuthError.cancelled
    }
    if case SdkError.AuthFailed(reason: .AccessDenied, _) = error {
      return AuthError.cancelled
    }
    return error
  }
}
