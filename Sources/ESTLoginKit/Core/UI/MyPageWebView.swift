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
/// 로그인 시 저장된 세션 쿠키(`WKWebsiteDataStore.default()`)를 공유하므로 별도 인증 없이 접근됩니다.
/// 마이페이지에서 비밀번호 변경 / 회원 탈퇴가 발생하면 `onPasswordChanged` / `onAccountDeleted`
/// 콜백이 호출됩니다. (토큰 재발급·로그아웃 등 실제 처리는 호스트가 담당)
///
/// URL은 `await ESTLoginManager.shared.mypageURL` 로 얻어 전달하세요.
/// ```swift
/// .sheet(isPresented: $showMyPage) {
///   MyPageWebView(
///     url: myPageURL,
///     onPasswordChanged: { /* silent=true 로 토큰 재발급 */ },
///     onAccountDeleted: { /* 로그아웃 처리 */ }
///   )
/// }
/// ```
public struct MyPageWebView: UIViewControllerRepresentable {

  private let url: URL
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onPasswordChanged: (() -> Void)?
  private let onAccountDeleted: (() -> Void)?

  public init(
    url: URL = ESTLoginManager.shared.mypageURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil
  ) {
    self.url = url
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
  }

  public func makeUIViewController(context: Context) -> ESTOneWebViewController {
    ESTOneWebViewController(
      url: url,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onPasswordChanged: onPasswordChanged,
      onAccountDeleted: onAccountDeleted
    )
  }

  public func updateUIViewController(_ uiViewController: ESTOneWebViewController, context: Context) {}
}
