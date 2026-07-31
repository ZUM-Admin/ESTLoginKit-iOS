//
//  MyPageWebView.swift
//  ESTLoginKit
//
//  Created by ESTAID on 6/25/26.
//

import SwiftUI
import WebKit

/// 마이페이지 진입용 SwiftUI 뷰.
///
/// 유효한 accessToken만 넘기면 SDK가 ssoToken 발급 → SSO 부트스트랩 → 마이페이지 진입까지
/// 처리합니다. 발급 중에는 로딩 인디케이터가 표시되고, 실패(만료 토큰 등)하면 `onError`가
/// 호출됩니다. (화면을 닫는 것은 호스트 몫)
///
/// 마이페이지에서 비밀번호 변경 / 회원 탈퇴가 발생하면 `onPasswordChanged` / `onAccountDeleted`
/// 콜백이 호출됩니다. (토큰 재발급·로그아웃 등 실제 처리는 호스트가 담당)
///
/// ```swift
/// .sheet(isPresented: $showMyPage) {
///   MyPageWebView(
///     accessToken: accessToken,
///     onPasswordChanged: { /* silent=true 로 토큰 재발급 */ },
///     onAccountDeleted: { /* 로그아웃 처리 */ },
///     onError: { _ in showMyPage = false }
///   )
/// }
/// ```
public struct MyPageWebView: View {

  private enum Source {
    /// 열 때마다 ssoToken을 새로 발급해 부트스트랩 (권장)
    case accessToken(String)
    /// 이미 만들어 둔 요청으로 진입 (부트스트랩 요청 또는 쿠키 의존 직접 진입)
    case request(URLRequest)
  }

  private let source: Source
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onPasswordChanged: (() -> Void)?
  private let onAccountDeleted: (() -> Void)?
  private let onError: ((Error) -> Void)?

  @State private var resolvedRequest: URLRequest?

  /// 권장 진입점. 유효한 accessToken을 넘기면 열 때마다 ssoToken을 새로 발급해 웹 세션을 수립한다.
  ///
  /// - Parameters:
  ///   - accessToken: 앱이 보유한 유효한 accessToken. 만료 판단·갱신은 앱 책임.
  ///   - onError: ssoToken 발급 실패 시 호출. 만료 토큰이면 `AuthError.server(statusCode: 401)`.
  public init(
    accessToken: String,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    onError: ((Error) -> Void)? = nil
  ) {
    self.source = .accessToken(accessToken)
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.onError = onError
  }

  /// 직접 만든 요청으로 여는 경우. 예: `authorizedMypageRequest(accessToken:)`로 만든 부트스트랩 요청.
  public init(
    request: URLRequest,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil
  ) {
    self.source = .request(request)
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.onError = nil
  }

  /// 세션 쿠키가 살아있을 때 URL로 직접 여는 경우. 쿠키가 없으면 로그인 화면이 뜨므로
  /// 일반적으로는 `init(accessToken:)`을 사용하세요.
  public init(
    url: URL = ESTLoginManager.shared.mypageURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil
  ) {
    self.init(
      request: URLRequest(url: url),
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted
    )
  }

  public var body: some View {
    switch source {
    case .request(let request):
      webView(request)

    case .accessToken(let accessToken):
      if let resolvedRequest {
        webView(resolvedRequest)
      } else {
        ProgressView()
          .task { await resolveRequest(accessToken: accessToken) }
      }
    }
  }

  private func webView(_ request: URLRequest) -> some View {
    MyPageWebRepresentable(
      request: request,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted
    )
  }

  private func resolveRequest(accessToken: String) async {
    ESTLog.debug("mypage bootstrap — resolving")
    do {
      let request = try await ESTLoginManager.shared
        .authorizedMypageRequest(accessToken: accessToken)
      ESTLog.debug("mypage bootstrap — loading: \(request.url?.redactedForLog ?? "")")
      resolvedRequest = request
    } catch {
      ESTLog.error("mypage bootstrap failed — \(error)")
      onError?(error)
    }
  }
}

// MARK: - Representable

private struct MyPageWebRepresentable: UIViewControllerRepresentable {

  let request: URLRequest
  let externalUserAgent: String?
  let inspectable: Bool
  let onWebViewCreated: ((WKWebView) -> Void)?
  let onPasswordChanged: (() -> Void)?
  let onAccountDeleted: (() -> Void)?

  func makeUIViewController(context: Context) -> WebViewController {
    WebViewController(
      request: request,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted
    )
  }

  func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}

  static func dismantleUIViewController(_ uiViewController: WebViewController, coordinator: ()) {
    uiViewController.teardown()
  }
}
