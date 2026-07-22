//
//  SSOToken.swift
//  ESTLoginKit
//
//  SSO 토큰 발급 — 웹뷰 세션/쿠키에 의존하지 않도록, 앱이 주입한 accessToken으로
//  일회성 SSO 토큰(유효 60초)을 발급받아 웹의 부트스트랩 URL로 전달한다.
//
//    GET {baseURL}/webview/sso-login?code={ssoToken}&redirect_url={URL인코딩된 내부 경로}
//
//  웹은 code를 검증해 자체 세션 쿠키를 수립한 뒤 redirect_url로 이동시키므로,
//  쿠키가 없는 기기/상태에서도 마이페이지·본인인증 웹뷰를 열 수 있다.
//  code가 만료 등으로 실패하면 웹이 기존 세션을 정리하고 로그인 화면으로 보내며,
//  로그인 후 redirect_url로 복귀하므로 앱의 별도 처리는 필요 없다.
//
//  SDK는 stateless: 토큰 저장·갱신·만료 판단은 전부 앱 책임이다. SDK는 호출 시점에
//  유효한 accessToken을 파라미터로 받는다고 가정하고, 만료 등 실패는 구분 가능한
//  에러(AuthError.server(statusCode: 401) 등)로 던진다. 갱신 후 재호출은 앱 몫.
//

import Foundation

extension ESTLoginManager {

  /// 일회성 SSO 토큰을 발급받는다.
  ///
  /// `GET {apiBaseURL}/auth/sso/sso-token` (Authorization: Bearer)
  ///
  /// - Parameter accessToken: 앱이 보유한 **유효한** accessToken. 만료 판단·갱신은 앱 책임이며,
  ///   만료된 토큰이면 `AuthError.server(statusCode: 401)`이 던져진다. 갱신 후 재호출은 앱 몫.
  /// - Returns: AES256 암호화된 일회성 SSO 토큰 (유효 60초, 파싱 금지)
  public func issueSSOToken(accessToken: String) async throws -> String {
    guard let config = Self.configuration else { throw AuthError.notInitialized }
    return try await requestSSOToken(apiBaseURL: config.apiBaseURL, accessToken: accessToken)
  }

  /// 마이페이지로 이동하는 SSO 부트스트랩 요청. 웹이 code 검증 후 자체 세션을 수립하고 이동시킨다.
  ///
  /// ssoToken은 유효 60초이므로 웹뷰를 여는 시점마다 새로 발급받아야 한다.
  /// (미리 발급해 두면 만료돼 사용자가 불필요하게 로그인 화면을 보게 된다)
  ///
  /// - Parameter accessToken: 앱이 보유한 유효한 accessToken. 만료 시 `AuthError.server(statusCode: 401)`.
  public func authorizedMypageRequest(accessToken: String) async throws -> URLRequest {
    let ssoToken = try await issueSSOToken(accessToken: accessToken)
    return URLRequest(
      url: Self.ssoLoginURL(redirectURL: Self.redirectURLValue(from: mypageURL), ssoToken: ssoToken)
    )
  }

  /// 본인인증으로 이동하는 SSO 부트스트랩 요청.
  ///
  /// - Parameter accessToken: 앱이 보유한 유효한 accessToken. 만료 시 `AuthError.server(statusCode: 401)`.
  public func authorizedVerificationRequest(
    accessToken: String,
    callbackURL: String? = nil
  ) async throws -> URLRequest {
    let ssoToken = try await issueSSOToken(accessToken: accessToken)
    return URLRequest(
      url: Self.ssoLoginURL(
        redirectURL: Self.redirectURLValue(from: verificationURL(callbackURL: callbackURL)),
        ssoToken: ssoToken
      )
    )
  }

  private func requestSSOToken(apiBaseURL: String, accessToken: String) async throws -> String {
    guard let url = URL(string: "\(apiBaseURL)/auth/sso/sso-token") else {
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

    return try JSONDecoder().decode(SSOTokenResponseDTO.self, from: data).result.ssoToken
  }

  /// SSO 부트스트랩 URL을 만든다.
  /// `GET {baseURL}/webview/sso-login?code={ssoToken}&redirect_url={인코딩된 내부 경로}`
  /// - Parameter redirectURL: 세션 수립 후 이동할 est 내부 경로(자체 쿼리 포함, 미인코딩 원본).
  ///   nil이면 생략되어 홈(/)으로 이동한다. 외부 URL은 웹이 홈으로 대체한다.
  static func ssoLoginURL(redirectURL: String?, ssoToken: String) -> URL {
    var components = URLComponents(string: "\(baseURL)/webview/sso-login")!
    var query = "code=\(queryEncoded(ssoToken))"
    if let redirectURL {
      query += "&redirect_url=\(queryEncoded(redirectURL))"
    }
    components.percentEncodedQuery = query
    return components.url!
  }

  /// 목적지 URL에서 redirect_url 값(path + query)을 추출한다. 예: `/webview/verification?client_id=1`
  static func redirectURLValue(from url: URL) -> String {
    let query = url.query.map { "?\($0)" } ?? ""
    return url.path + query
  }

  /// 쿼리 값 인코딩. 토큰은 AES256 암호화 문자열이라 `+` `=` `/` 등을 포함할 수 있고
  /// `+`를 그대로 두면 서버가 공백으로 해석하므로 명시적으로 퍼센트 인코딩한다.
  /// redirect_url도 자체 쿼리(`?` `&` `=`)를 포함하므로 목적지 경로 전체를 1회 인코딩해 전달한다.
  /// (`:`는 urlQueryAllowed에 포함되지만 callbackURL의 `https:` 등을 encodeURIComponent와
  ///  동일하게 처리하기 위해 함께 인코딩한다)
  private static func queryEncoded(_ value: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "+&=?/:")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }
}
