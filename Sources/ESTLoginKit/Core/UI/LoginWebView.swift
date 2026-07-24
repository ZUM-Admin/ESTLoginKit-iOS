//
//  LoginWebView.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/11/26.
//

import SwiftUI
import WebKit

/// 로그인 진입용 SwiftUI 뷰.
///
/// - `init(url:)` / `init(request:)` — URL·커스텀 요청으로 직접 진입 (신규 로그인 등)
/// - `init(accessToken:)` — 마이페이지/본인인증과 동일하게 ssoToken 발급 → `/auth/sso-login` 부트스트랩 후
///   로그인 페이지로 진입. 발급 중 로딩 표시, 실패 시 `onError`.
public struct LoginWebView: View {

  private enum Source {
    /// 열 때마다 부트스트랩(`/auth/sso-login`)으로 진입. accessToken이 nil이면 code 없이 열고 웹이 로그인 페이지로 라우팅
    case accessToken(String?, redirectURL: String?, state: String?)
    /// 이미 만들어 둔 요청으로 진입 (url 또는 커스텀 요청)
    case request(URLRequest)
  }

  private let source: Source
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onPasswordChanged: (() -> Void)?
  private let onAccountDeleted: (() -> Void)?
  private let onError: ((Error) -> Void)?
  private let completion: ((String?) -> Void)?

  @State private var resolvedRequest: URLRequest?

  public init(
    url: URL = ESTLoginManager.shared.loginURL(),
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    completion: ((String?) -> Void)? = nil
  ) {
    self.init(
      request: URLRequest(url: url),
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted,
      completion: completion
    )
  }

  /// SSO 부트스트랩 등 커스텀 요청으로 여는 경우. 예: `authorizedMypageRequest()`
  public init(
    request: URLRequest,
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    completion: ((String?) -> Void)? = nil
  ) {
    self.source = .request(request)
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.onError = nil
    self.completion = completion
  }

  /// accessToken 기반 진입 — 마이페이지/본인인증과 동일 방식.
  ///
  /// 유효한 accessToken으로 ssoToken을 발급해 `/auth/sso-login` 부트스트랩 후 로그인 페이지로 진입한다.
  /// 발급 중에는 로딩 인디케이터가 표시되고, 실패(만료 토큰 등)하면 `onError`가 호출된다.
  ///
  /// - Parameters:
  ///   - accessToken: 앱이 보유한 유효한 accessToken. 만료 판단·갱신은 앱 책임.
  ///   - onError: ssoToken 발급 실패 시 호출. 만료 토큰이면 `AuthError.server(statusCode: 401)`.
  public init(
    accessToken: String?,
    redirectURL: String? = nil,
    state: String? = nil,
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    onError: ((Error) -> Void)? = nil,
    completion: ((String?) -> Void)? = nil
  ) {
    self.source = .accessToken(accessToken, redirectURL: redirectURL, state: state)
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.onError = onError
    self.completion = completion
  }

  public var body: some View {
    switch source {
    case .request(let request):
      webView(request)

    case .accessToken(let token, let redirectURL, let state):
      if let resolvedRequest {
        webView(resolvedRequest)
      } else {
        ProgressView()
          .task { await resolveRequest(accessToken: token, redirectURL: redirectURL, state: state) }
      }
    }
  }

  private func webView(_ request: URLRequest) -> some View {
    LoginWebRepresentable(
      request: request,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted,
      completion: completion
    )
  }

  private func resolveRequest(accessToken: String?, redirectURL: String?, state: String?) async {
    ESTLog.debug("login bootstrap — resolving")
    do {
      let request = try await ESTLoginManager.shared.authorizedLoginRequest(
        accessToken: accessToken,
        redirectURL: redirectURL,
        state: state
      )
      ESTLog.debug("login bootstrap — loading: \(request.url?.redactedForLog ?? "")")
      resolvedRequest = request
    } catch {
      ESTLog.error("login bootstrap failed — \(error)")
      onError?(error)
    }
  }
}

// MARK: - Representable

private struct LoginWebRepresentable: UIViewControllerRepresentable {

  let request: URLRequest
  let callbackURL: String?
  let externalUserAgent: String?
  let inspectable: Bool
  let onWebViewCreated: ((WKWebView) -> Void)?
  let onPasswordChanged: (() -> Void)?
  let onAccountDeleted: (() -> Void)?
  let completion: ((String?) -> Void)?

  func makeUIViewController(context: Context) -> ESTOneWebViewController {
    ESTOneWebViewController(
      request: request,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted,
      completion: completion
    )
  }

  func updateUIViewController(_ uiViewController: ESTOneWebViewController, context: Context) {}

  static func dismantleUIViewController(_ uiViewController: ESTOneWebViewController, coordinator: ()) {
    uiViewController.teardown()
  }
}
