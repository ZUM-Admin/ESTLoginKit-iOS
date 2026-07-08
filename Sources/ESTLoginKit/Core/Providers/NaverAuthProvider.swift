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

  @MainActor
  private func requestLogin() async throws -> (access: String, refresh: String) {
    return try await withCheckedThrowingContinuation { continuation in
      NidOAuth.shared.requestLogin { result in
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
