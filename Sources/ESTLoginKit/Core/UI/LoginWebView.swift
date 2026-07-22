//
//  LoginWebView.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/11/26.
//

import SwiftUI
import WebKit

public struct LoginWebView: UIViewControllerRepresentable {

  private let request: URLRequest
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onPasswordChanged: (() -> Void)?
  private let onAccountDeleted: (() -> Void)?
  private let completion: ((String?) -> Void)?

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
    self.request = request
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.completion = completion
  }

  public func makeUIViewController(context: Context) -> ESTOneWebViewController {
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

  public func updateUIViewController(_ uiViewController: ESTOneWebViewController, context: Context) {}

  public static func dismantleUIViewController(_ uiViewController: ESTOneWebViewController, coordinator: ()) {
    uiViewController.teardown()
  }
}
