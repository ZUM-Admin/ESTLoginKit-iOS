//
//  EstoneAuth.swift
//  ESTLoginKit-iOS-Example
//
//  ssoToken(OAuth code) → EST 통합회원 access/refresh 토큰 발급.
//
//  흐름:
//    1) POST /sso/access-token   {ssoToken, clientId}                    → accessToken
//    2) POST /sso/refresh-token  {ssoToken, clientId} + Bearer(1의 결과) → refreshToken
//    3) POST /refresh-sso        {accessToken, refreshToken}             → 둘 다 재발급
//

import Foundation

struct EstoneToken {
  let accessToken: String
  let refreshToken: String
  /// 만료 "시각" (ms epoch). 초 단위 duration이 아님에 주의.
  let expiresIn: Int

  var expiryDate: Date { Date(timeIntervalSince1970: Double(expiresIn) / 1000) }
}

enum EstoneAuthError: Error {
  case invalidResponse(status: Int, body: String)
  case missingField(String)
}

enum EstoneAuth {
  // 백엔드 주소·클라이언트 ID는 Config.xcconfig에서 주입된다. (소스에 하드코딩 없음)
  static var baseURL: String { "https://\(ExampleConfig.apiHost)/auth" }
  static var clientId: String { ExampleConfig.clientID }

  private struct SSORequest: Encodable {
    let ssoToken: String
    let clientId: String
  }

  private struct RenewRequest: Encodable {
    let accessToken: String
    let refreshToken: String
  }

  private struct Wrapper: Decodable {
    let message: String?
    let result: TokenDTO
  }

  private struct TokenDTO: Decodable {
    let grantType: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
  }

  /// ssoToken(OAuth code) → access/refresh 2단계 발급.
  static func issueToken(ssoToken: String) async throws -> EstoneToken {
    let body = SSORequest(ssoToken: ssoToken, clientId: clientId)

    let accessDTO = try await post("/sso/access-token", body: body)
    guard let accessToken = accessDTO.accessToken, !accessToken.isEmpty else {
      throw EstoneAuthError.missingField("accessToken")
    }

    let refreshDTO = try await post("/sso/refresh-token", body: body, bearer: accessToken)
    guard let refreshToken = refreshDTO.refreshToken, !refreshToken.isEmpty else {
      throw EstoneAuthError.missingField("refreshToken")
    }

    return EstoneToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: refreshDTO.expiresIn ?? accessDTO.expiresIn ?? 0
    )
  }

  /// access/refresh 둘 다 재발급.
  static func renewToken(_ token: EstoneToken) async throws -> EstoneToken {
    let dto = try await post(
      "/refresh-sso",
      body: RenewRequest(accessToken: token.accessToken, refreshToken: token.refreshToken)
    )
    guard let accessToken = dto.accessToken, !accessToken.isEmpty else {
      throw EstoneAuthError.missingField("accessToken")
    }
    guard let refreshToken = dto.refreshToken, !refreshToken.isEmpty else {
      throw EstoneAuthError.missingField("refreshToken")
    }
    return EstoneToken(accessToken: accessToken, refreshToken: refreshToken, expiresIn: dto.expiresIn ?? 0)
  }

  private static func post(
    _ path: String,
    body: some Encodable,
    bearer: String? = nil
  ) async throws -> TokenDTO {
    var request = URLRequest(url: URL(string: baseURL + path)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let bearer {
      request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
    guard (200..<300).contains(status) else {
      throw EstoneAuthError.invalidResponse(
        status: status,
        body: String(data: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(Wrapper.self, from: data).result
  }
}

// MARK: - 저장 (예제 앱이므로 UserDefaults 사용. 실서비스는 Keychain 권장)

enum TokenStore {
  private static let accessKey = "estone.accessToken"
  private static let refreshKey = "estone.refreshToken"
  private static let expiresKey = "estone.expiresIn"

  static func save(_ token: EstoneToken) {
    let defaults = UserDefaults.standard
    defaults.set(token.accessToken, forKey: accessKey)
    defaults.set(token.refreshToken, forKey: refreshKey)
    defaults.set(token.expiresIn, forKey: expiresKey)
  }

  static func load() -> EstoneToken? {
    let defaults = UserDefaults.standard
    guard let access = defaults.string(forKey: accessKey),
          let refresh = defaults.string(forKey: refreshKey)
    else { return nil }
    return EstoneToken(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: defaults.integer(forKey: expiresKey)
    )
  }

  static func clear() {
    let defaults = UserDefaults.standard
    [accessKey, refreshKey, expiresKey].forEach(defaults.removeObject(forKey:))
  }
}
