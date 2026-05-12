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
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let completion: ((String?) -> Void)?

  private let webView: WKWebView
  private var initialState: String?

  public init(
    url: URL,
    callbackURL: String? = nil,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    completion: ((String?) -> Void)? = nil
  ) {
    self.url = url
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.completion = completion
    self.initialState = url.queryValue(for: "state")

    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.default()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true

    let webView = WKWebView(frame: CGRect.zero, configuration: config)

    if #available(iOS 16.4, *) {
      webView.isInspectable = inspectable
    }

    webView.allowsBackForwardNavigationGestures = true
    self.webView = webView
    super.init(nibName: nil, bundle: nil)
    onWebViewCreated?(webView)
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
    self.webView.uiDelegate = self
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

  private var androidUserAgent: String {
    // 실제 Chrome Android UA와 동일 포맷. `Build/...` 토큰은 Android WebView 전용
    // 시그널이라 구글이 이걸 보면 embedded browser로 차단("안전하지 않을 수 있습니다").
    var ua = "Mozilla/5.0 (Linux; Android 15; SM-S928N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.91 Mobile Safari/537.36"
    if let externalUserAgent {
      ua += " \(externalUserAgent)"
    }
    return ua
  }

  private static let googleLoginURLFragments: [String] = [
    // zum 진입점에서 미리 Android UA로 전환해야 안전.
    // accounts.google.com 도달 후 교체하면 redirect 체인상 iOS UA로 이미 요청되어
    // 구글이 embedded browser로 차단할 수 있음.
    "sign.zum.com/oauth2/authorization/google",
    "accounts.google.com",
    "accounts.google.co.kr",
    "sign.zum.com/oauth2/authorization/facebook",
  ]

  private func isGoogleLoginURL(_ url: URL) -> Bool {
    let absolute = url.absoluteString
    return Self.googleLoginURLFragments.contains { absolute.contains($0) }
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

    // Google OAuth 계열 URL이면 Android UA로 전환 (그대로 allow, cancel/reload 금물 — 흰 화면 원인)
    if isGoogleLoginURL(navigatingURL) {
      print("[LoginWebViewController] Google login URL — switching to Android UA")
      webView.customUserAgent = androidUserAgent
    }

    // callback URL → ssoToken 추출 후 콜백 전달
    if let callbackURL,
       navigatingURL.absoluteString.hasPrefix(callbackURL) {
      if let ssoToken = navigatingURL.queryValue(for: "code") {
        print("[LoginWebViewController] callback with ssoToken — completing")
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


// MARK: - WKUIDelegate

// Google OAuth는 embedded browser 판정을 위해 JS dialog / window.open 같은
// 표준 브라우저 기능이 살아있는지 본다. uiDelegate 없이 두면 전부 무시돼
// "브라우저 또는 앱이 안전하지 않을 수 있습니다"로 이어질 수 있음.
extension LoginWebViewController: WKUIDelegate {
  public func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    // target="_blank" / window.open() 은 동일 webView에서 이어서 로드
    if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
      webView.load(URLRequest(url: url))
    }
    return nil
  }

  public func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> Void
  ) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
    present(alert, animated: true)
  }

  public func webView(
    _ webView: WKWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (Bool) -> Void
  ) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
    alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
    present(alert, animated: true)
  }

  public func webView(
    _ webView: WKWebView,
    runJavaScriptTextInputPanelWithPrompt prompt: String,
    defaultText: String?,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (String?) -> Void
  ) {
    let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
    alert.addTextField { $0.text = defaultText }
    alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(nil) })
    alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
      completionHandler(alert.textFields?.first?.text)
    })
    present(alert, animated: true)
  }
}
