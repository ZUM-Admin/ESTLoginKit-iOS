//
//  IdentityVerificationView.swift
//  ESTLoginKit
//
//  본인인증 진입용 SwiftUI 뷰.
//

import SwiftUI
import WebKit

/// 본인인증 화면.
///
/// 유효한 accessToken만 넘기면 SDK가 ssoToken 발급 → SSO 부트스트랩 → 본인인증 진입까지
/// 처리합니다. 발급 중에는 로딩 인디케이터가 표시되고, 실패(만료 토큰 등)하면 `onResult`로
/// `.failure`가 전달됩니다.
///
/// 인증 회원 승격과 CI 충돌 해소는 웹뷰가 자체 처리하고, SDK는 그 결과만 `onResult`로 전달합니다.
///
/// **언제 띄울지(정책)와 present/dismiss는 호스트 책임입니다.** 인증 여부는
/// `ESTLoginManager.shared.verificationStatus(accessToken:)`로 조회하세요.
///
/// ```swift
/// .sheet(isPresented: $showVerification) {
///   IdentityVerificationView(accessToken: accessToken) { result in
///     showVerification = false
///     if case .success(let v) = result { /* v.token으로 세션 재수립 */ }
///   }
///   .ignoresSafeArea()
/// }
/// ```
public struct IdentityVerificationView: View {

  private enum Source {
    /// 열 때마다 ssoToken을 새로 발급해 부트스트랩 (권장)
    case accessToken(String)
    /// 이미 만들어 둔 요청으로 진입 (부트스트랩 요청 또는 쿠키 의존 직접 진입)
    case request(URLRequest)
  }

  private let source: Source
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onResult: (Result<VerificationResult, AuthError>) -> Void

  @State private var resolvedRequest: URLRequest?

  /// 권장 진입점. 유효한 accessToken을 넘기면 열 때마다 ssoToken을 새로 발급해 웹 세션을 수립한다.
  ///
  /// - Parameters:
  ///   - accessToken: 앱이 보유한 유효한 accessToken. 만료 판단·갱신은 앱 책임.
  ///   - callbackURL: 완료 시 리다이렉트될 앱 콜백 URL. 기본값은 `appCallbackURL`.
  ///     결과는 이 리다이렉트로만 도착하므로 `nil`을 넘기면 `onResult`가 호출되지 않는다.
  ///   - onResult: 발급 실패 시 `.failure(.server(statusCode: 401))` 등,
  ///     사용자 취소 시 `.failure(.cancelled)`, 승격/병합 실패 시 `.failure(.verificationFailed)`.
  public init(
    accessToken: String,
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
  ) {
    self.source = .accessToken(accessToken)
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onResult = onResult
  }

  /// 직접 만든 요청으로 여는 경우. 예: `authorizedVerificationRequest(accessToken:)`로 만든 부트스트랩 요청.
  public init(
    request: URLRequest,
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
  ) {
    self.source = .request(request)
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onResult = onResult
  }

  /// 세션 쿠키가 살아있을 때 URL로 직접 여는 경우. 쿠키가 없으면 로그인 화면이 뜨므로
  /// 일반적으로는 `init(accessToken:)`을 사용하세요.
  ///
  /// - Parameter url: 기본값은 `verificationURL(callbackURL:)`. 직접 넘기면 `callbackURL` 조합을 대체합니다.
  public init(
    url: URL? = nil,
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
  ) {
    self.init(
      request: URLRequest(url: url ?? ESTLoginManager.shared.verificationURL(callbackURL: callbackURL)),
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onResult: onResult
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
    IdentityVerificationRepresentable(
      request: request,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onResult: onResult
    )
  }

  private func resolveRequest(accessToken: String) async {
    ESTLog.debug("verification bootstrap — resolving")
    do {
      let request = try await ESTLoginManager.shared.authorizedVerificationRequest(
        accessToken: accessToken,
        callbackURL: callbackURL
      )
      ESTLog.debug("verification bootstrap — loading: \(request.url?.redactedForLog ?? "")")
      resolvedRequest = request
    } catch {
      ESTLog.error("verification bootstrap failed — \(error)")
      onResult(.failure(error as? AuthError ?? .unknown(error)))
    }
  }
}

// MARK: - Representable

private struct IdentityVerificationRepresentable: UIViewControllerRepresentable {

  let request: URLRequest
  let callbackURL: String?
  let externalUserAgent: String?
  let inspectable: Bool
  let onWebViewCreated: ((WKWebView) -> Void)?
  let onResult: (Result<VerificationResult, AuthError>) -> Void

  func makeUIViewController(context: Context) -> ESTOneWebViewController {
    ESTOneWebViewController(
      request: request,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onVerificationResult: onResult
    )
  }

  func updateUIViewController(_ uiViewController: ESTOneWebViewController, context: Context) {}

  static func dismantleUIViewController(_ uiViewController: ESTOneWebViewController, coordinator: ()) {
    uiViewController.teardown()
  }
}
