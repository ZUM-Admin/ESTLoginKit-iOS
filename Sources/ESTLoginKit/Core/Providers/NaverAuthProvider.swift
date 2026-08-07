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
    let tokens = try await requestLogin()

    // 토큰 획득 성공 직후, 콜백 발화 전에 프로필 API 1회 호출해 email/ci 조회.
    // 조회 실패/미동의/빈 값이면 해당 값 없이 진행 (로그인 실패로 만들지 않음).
    let profile = await fetchProfile(accessToken: tokens.access)

    return AuthResult(
      authorizeToken: tokens.access,
      refreshToken: tokens.refresh,
      ci: profile.ci,
      email: profile.email
    )
  }

  /// 네이버 로그인 — `requestLogin` 대신 `reauthenticate`(`auth_type=reauthenticate`)를 쓴다.
  ///
  /// 인앱 브라우저(ASWebAuthenticationSession)는 Safari와 쿠키를 공유하고, 네이버 SDK가
  /// `prefersEphemeralWebBrowserSession`을 `false`로 고정해둬서 이 쿠키를 끌 방법이 없다.
  /// 그 결과 `requestLogin`은 앱에서 로그아웃해도 남아있는 네이버 세션으로 자동 통과해버려
  /// 다른 계정으로 로그인할 수가 없다. 재인증은 쿠키 세션을 무시하고 로그인 화면을 띄우되
  /// 앱 연동은 유지하므로 이미 동의한 항목을 다시 묻지 않는다(연동 해제와 다른 점).
  ///
  /// 네이버앱으로 로그인하는 경로에서는 SDK가 authType을 `.default`로 되돌리므로 이 설정이
  /// 무시된다 — 그쪽은 네이버앱에 로그인된 계정을 따라가며, 계정 전환도 네이버앱에서 한다.
  @MainActor
  private func requestLogin() async throws -> (access: String, refresh: String) {
    return try await withCheckedThrowingContinuation { continuation in
      NidOAuth.shared.reauthenticate { result in
        switch result {
        case .success(let loginResult):
          continuation.resume(returning: (
            loginResult.accessToken.tokenString,
            loginResult.refreshToken.tokenString
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

  /// 네이버 프로필에서 email/ci 조회. 실패/미동의/빈 값이면 "" 반환 (절대 throw하지 않음).
  /// getUserProfile은 nid/me 응답(response)을 [String: String]로 그대로 돌려주므로
  /// 승인된 제공 항목에 한해 profile["email"], profile["ci"] 등으로 접근 가능.
  /// 참고: 네이버 개발자센터 앱에 "이메일 주소" / "CI(연계정보)" 제공 동의 항목이 설정되어 있어야 하며,
  /// 사용자가 동의를 거부하면 값이 내려오지 않는다.
  @MainActor
  private func fetchProfile(accessToken: String) async -> (email: String, ci: String) {
    return await withCheckedContinuation { continuation in
      NidOAuth.shared.getUserProfile(accessToken: accessToken) { result in
        switch result {
        case .success(let profile):
          continuation.resume(returning: (profile["email"] ?? "", profile["ci"] ?? ""))
        case .failure:
          continuation.resume(returning: ("", ""))
        }
      }
    }
  }
}
