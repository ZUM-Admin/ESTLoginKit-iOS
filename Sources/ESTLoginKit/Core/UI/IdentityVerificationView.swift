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
/// 로그인 시 저장된 세션 쿠키(`WKWebsiteDataStore.default()`)를 공유하므로 임시 회원 세션이 그대로 전달됩니다.
/// 인증 회원 승격과 CI 충돌 해소는 웹뷰가 자체 처리하고, SDK는 그 결과만 `onResult`로 전달합니다.
///
/// **언제 띄울지(정책)와 present/dismiss는 호스트 책임입니다.** 인증 여부는
/// `ESTLoginManager.shared.verificationStatus(accessToken:)`로 조회하세요.
///
/// ```swift
/// .sheet(isPresented: $showVerification) {
///   IdentityVerificationView { result in
///     showVerification = false
///     if case .success(let v) = result { /* v.token으로 세션 재수립 */ }
///   }
///   .ignoresSafeArea()
/// }
/// ```
public struct IdentityVerificationView: UIViewControllerRepresentable {

  private let url: URL
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onResult: (Result<VerificationResult, AuthError>) -> Void

  /// - Parameters:
  ///   - url: 기본값은 `verificationURL(callbackURL:)`. 직접 넘기면 `callbackURL` 조합을 대체합니다.
  ///   - callbackURL: 브릿지 미등록 시 리다이렉트될 앱 콜백 URL. 브릿지가 우선이므로 생략해도 동작합니다.
  ///   - onResult: 사용자 취소 시 `.failure(.cancelled)`, 승격/병합 실패 시 `.failure(.verificationFailed)`.
  public init(
    url: URL? = nil,
    callbackURL: String? = nil,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
  ) {
    self.url = url ?? ESTLoginManager.shared.verificationURL(callbackURL: callbackURL)
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onResult = onResult
  }

  public func makeUIViewController(context: Context) -> ESTOneWebViewController {
    ESTOneWebViewController(
      url: url,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onVerificationResult: onResult
    )
  }

  public func updateUIViewController(_ uiViewController: ESTOneWebViewController, context: Context) {}

  public static func dismantleUIViewController(_ uiViewController: ESTOneWebViewController, coordinator: ()) {
    uiViewController.teardown()
  }
}
