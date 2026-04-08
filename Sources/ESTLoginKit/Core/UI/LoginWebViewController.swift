//
//  LoginWebViewController.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit
import WebKit

public final class LoginWebViewController: UIViewController {
  private let url: URL
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let completion: ((String?) -> Void)?

  private let webView: WKWebView
  private var initialState: String?
  private var originalUserAgent: String?

  private static let appCallbackPath = "https://estoneid.com/auth/app-callback"

  public init(
    url: URL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    completion: ((String?) -> Void)? = nil
  ) {
    self.url = url
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.completion = completion
    self.initialState = url.queryValue(for: "state")

    let config = WKWebViewConfiguration()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true

    let webView = WKWebView(frame: CGRect.zero, configuration: config)

    if #available(iOS 16.4, *) {
      webView.isInspectable = inspectable
    }
    
    webView.allowsBackForwardNavigationGestures = true
    self.webView = webView
    super.init(nibName: nil, bundle: nil)
    print("[LoginWebViewController] init — url: \(url)")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    registerMessageHandlers()
    setup()
    setupLayout()
  }

  private func registerMessageHandlers() {
    print("[LoginWebViewController] registering message handlers")
    WebViewMessage.allCases.forEach { message in
      self.webView.configuration.userContentController
        .removeScriptMessageHandler(forName: message.rawValue)
      self.webView.configuration.userContentController.add(
        LeakAvoider(delegate: self),
        name: message.rawValue
      )
      print("[LoginWebViewController] registered handler: \(message.rawValue)")
    }
  }

  private func setup() {
    self.webView.navigationDelegate = self
    self.webView.allowsBackForwardNavigationGestures = true
    print("[LoginWebViewController] loading url: \(self.url)")
    self.webView.load(URLRequest(url: self.url))

    if let externalUserAgent {
      addUserAgent(externalUserAgent)
    }
  }

  private func addUserAgent(_ userAgent: String) {
    self.webView.evaluateJavaScript("navigator.userAgent") { [weak self] result, error in
      guard let self,
            let result = result as? String
      else {
        return
      }

      self.webView.customUserAgent = result + " \(userAgent)"
      print("[LoginWebViewController] userAgent set: \(self.webView.customUserAgent ?? "")")
    }
  }

  private func setupLayout() {
    self.view.addSubview(self.webView)
    self.webView.frame = self.view.frame
  }
  // MARK: - Google Login UA Workaround

  private var isUsingAndroidUserAgent = false

  private var androidUserAgent: String {
    var ua = "Mozilla/5.0 (Linux; Android 15; SM-S928N Build/AP3A.240905.015.A2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.91 Mobile Safari/537.36"
    if let externalUserAgent {
      ua += " \(externalUserAgent)"
    }
    return ua
  }

  private static let googleLoginHosts: Set<String> = [
    "accounts.google.com",
    "accounts.google.co.kr",
  ]

  private func isGoogleLoginURL(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    return Self.googleLoginHosts.contains(host)
  }
}


// MARK: - WKNavigationDelegate

extension LoginWebViewController: WKNavigationDelegate {
  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    guard let navigatingURL = navigationAction.request.url else {
      decisionHandler(.allow)
      return
    }
    print("[LoginWebViewController] navigation: \(navigatingURL.absoluteString)")

    // Google OAuth URL 감지 시 Android UA로 교체 후 cancel → reload
    if isGoogleLoginURL(navigatingURL) && !isUsingAndroidUserAgent {
      print("[LoginWebViewController] Google login detected — switching to Android UA and reloading")
      originalUserAgent = webView.customUserAgent
      webView.customUserAgent = androidUserAgent
      isUsingAndroidUserAgent = true
      decisionHandler(.cancel)
      webView.load(URLRequest(url: navigatingURL))
      return
    }

    // Google 로그인 완료 후 원래 UA 복원
    if isUsingAndroidUserAgent && !isGoogleLoginURL(navigatingURL) {
      print("[LoginWebViewController] Google login done — restoring original UA")
      webView.customUserAgent = originalUserAgent
      isUsingAndroidUserAgent = false
    }

    // app-callback URL → ssoToken 추출 후 콜백 전달
    if navigatingURL.absoluteString.hasPrefix(Self.appCallbackPath) {
      if let ssoToken = navigatingURL.queryValue(for: "code") {
        print("[LoginWebViewController] app-callback with ssoToken — completing")
        decisionHandler(.cancel)
        completion?(ssoToken)
        return
      }
    }

    // state URL 매칭 → ssoToken 없이 콜백 전달
    if let state = initialState,
       navigatingURL.absoluteString.hasPrefix(state) {
      print("[LoginWebViewController] state url match — completing with url: \(navigatingURL.absoluteString)")
      decisionHandler(.allow)
      completion?(nil)
      return
    }

    decisionHandler(.allow)
  }

  public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    print("[LoginWebViewController] didStartProvisionalNavigation")
  }

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    print("[LoginWebViewController] didFinish — \(webView.url?.absoluteString ?? "")")
  }

  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    print("[LoginWebViewController] didFail — \(error)")
  }

  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    print("[LoginWebViewController] didFailProvisionalNavigation — \(error)")
  }
}


// MARK: - WKScriptMessageHandler

extension LoginWebViewController: WKScriptMessageHandler {
  public func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    print("[LoginWebViewController] message received — name: \(message.name), body: \(message.body)")

    guard let action = WebViewMessage(rawValue: message.name),
          let body = message.body as? String,
          let data = body.data(using: .utf8),
          let dto = action.decode(from: data)
    else {
      print("[LoginWebViewController] message parse failed — name: \(message.name)")
      return
    }

    handleAction(action, payload: dto)
  }

  private func handleAction(_ action: WebViewMessage, payload: Decodable) {
    switch action {
    case .requestSnsLogin:
      guard let loginDTO = payload as? RequestLoginDTO,
            let platform = LoginPlatform(rawValue: loginDTO.provider.rawValue)
      else {
        print("[LoginWebViewController] requestSnsLogin — invalid payload")
        return
      }

      print("[LoginWebViewController] requestSnsLogin — provider: \(loginDTO.provider.rawValue)")

      Task {
        do {
          let result = try await ESTLoginManager.shared.login(with: platform)
          print("[LoginWebViewController] login success — provider: \(loginDTO.provider.rawValue), token: \(result.authorizeToken.prefix(20))...")
          sendSuccessResult(
            SNSLoginSuccessPayload(
              provider: loginDTO.provider.rawValue,
              authorizeToken: result.authorizeToken,
              refreshToken: result.refreshToken,
              ci: result.ci,
              email: result.email
            )
          )
        } catch {
          print("[LoginWebViewController] login failed — provider: \(loginDTO.provider.rawValue), error: \(error)")
          sendErrorResult(
            SNSLoginErrorPayload(
              code: errorCode(from: error),
              message: error.localizedDescription,
              provider: loginDTO.provider.rawValue
            )
          )
        }
      }
    }
  }

  private func errorCode(from error: Error) -> String {
    guard let authError = error as? AuthError else { return "sdk_error" }
    switch authError {
    case .unknown(nil): return "cancelled"
    case .unknown:      return "sdk_error"
    case .unsupportedPlatform: return "sdk_error"
    }
  }

  @MainActor
  private func sendSuccessResult(_ payload: SNSLoginSuccessPayload) {
    guard let json = payload.jsonString else { return }
    print("[LoginWebViewController] sendSuccessResult — \(json)")
    webView.evaluateJavaScript("window.onNativeSnsLoginResult(\(json))")
  }

  @MainActor
  private func sendErrorResult(_ payload: SNSLoginErrorPayload) {
    guard let json = payload.jsonString else { return }
    print("[LoginWebViewController] sendErrorResult — \(json)")
    webView.evaluateJavaScript("window.onNativeSnsLoginError(\(json))")
  }
}
