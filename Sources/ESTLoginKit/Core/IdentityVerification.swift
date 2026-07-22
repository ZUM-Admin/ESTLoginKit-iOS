//
//  IdentityVerification.swift
//  ESTLoginKit
//
//  본인인증(Identity Verification) — 상태 조회 API.
//  상태(fact)는 SDK가 조회하고, 언제 인증을 요구할지(policy)는 앱이 결정한다.
//  SDK는 토큰을 보관하지 않으므로(stateless) 조회 시 호스트가 accessToken을 주입한다.
//

import Foundation

/// 회원 본인인증 상태.
public struct VerificationStatus {
  /// 응답 status == "CERTIFIED" 이면 true.
  public let isVerified: Bool
}

extension ESTLoginManager {

  /// 회원 본인인증 완료 여부를 조회한다.
  ///
  /// `GET {apiBaseURL}/members/v1/certification/status` (Authorization: Bearer)
  /// 인증 상태는 통합회원 계정 단위로 관리되어 모든 계열사에서 동일하게 조회된다.
  ///
  /// - Parameter accessToken: 토큰 교환으로 발급받은 accessToken (SDK 미보관, 호스트 주입).
  public func verificationStatus(accessToken: String) async throws -> VerificationStatus {
    guard let apiBaseURL = Self.configuration?.apiBaseURL else {
      throw AuthError.notInitialized
    }

    guard let url = URL(string: "\(apiBaseURL)/members/v1/certification/status") else {
      throw AuthError.unknown(nil)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    if !(200..<300).contains(statusCode) {
      throw AuthError.server(statusCode: statusCode)
    }

    let decoded = try JSONDecoder().decode(CertificationStatusResponseDTO.self, from: data)
    return VerificationStatus(isVerified: decoded.result.status == .certified)
  }
}
