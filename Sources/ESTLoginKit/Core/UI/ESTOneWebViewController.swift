//
//  ESTOneWebViewController.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit
import WebKit

public final class ESTOneWebViewController: UIViewController {
  private let url: URL
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onPasswordChanged: (() -> Void)?
  private let onAccountDeleted: (() -> Void)?
  private let completion: ((String?) -> Void)?

  // teardown에서 참조를 끊어 순환을 해제하기 위해 var(IUO). Hackle 브릿지가 delegate(self)를 강참조하지만,
  // VC가 webView 참조를 놓으면 webView가 dealloc되며 associated된 브릿지도 사라져 순환이 끊긴다.
  private var webView: WKWebView!
  private var initialState: String?

  private var ssoToken: String?

  public init(
    url: URL,
    callbackURL: String? = nil,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    completion: ((String?) -> Void)? = nil
  ) {
    self.url = url
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.completion = completion
    self.initialState = url.queryValue(for: "state")

    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.default()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true

    // 기본 UA 뒤에 앱 식별 토큰을 append (예: "... zumapp/3.13.3").
    // customUserAgent(전체 교체)와 달리 webView 생성 시점에 박혀서 첫 로드부터 적용되고,
    // navigator.userAgent를 비동기로 읽어 붙일 필요가 없다.
    // Google 로그인 시에는 decidePolicyFor에서 customUserAgent로 덮어써 우회한다(우선순위 높음).
    if let externalUserAgent {
      config.applicationNameForUserAgent = externalUserAgent
    }

    let webView = WKWebView(frame: CGRect.zero, configuration: config)

    if #available(iOS 16.4, *) {
      webView.isInspectable = inspectable
    }

    webView.allowsBackForwardNavigationGestures = true
    self.webView = webView
    super.init(nibName: nil, bundle: nil)
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
    WebViewMessage.allCases.forEach { message in
      self.webView.configuration.userContentController
        .removeScriptMessageHandler(forName: message.rawValue)
      self.webView.configuration.userContentController.add(
        LeakAvoider(delegate: self),
        name: message.rawValue
      )
    }
  }

  private func setup() {
    self.webView.navigationDelegate = self
    self.webView.uiDelegate = self
    self.webView.allowsBackForwardNavigationGestures = true

    // delegate 다 붙은 뒤 콜백 → 호스트가 setWebViewBridge 호출하면 Hackle이 우리 delegate를 wrap
    onWebViewCreated?(self.webView)

    self.webView.load(URLRequest(url: self.url))
  }

  private func setupLayout() {
    self.view.addSubview(self.webView)
    self.webView.frame = self.view.frame
  }

  /// SwiftUI 뷰 해제(dismantleUIViewController) 시 호출. 메시지 핸들러/델리게이트/로딩 정리로 누수 방지.
  func teardown() {
    WebViewMessage.allCases.forEach {
      webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
    }
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
    webView.removeFromSuperview()
    webView = nil  // VC의 강참조 해제 → webView(+associated Hackle 브릿지) dealloc → 순환 끊김
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
    // 감지 즉시 cancel→reload로 Android UA를 적용한다.
    // (decidePolicyFor에서 UA만 바꾸면 현재 navigation에는 반영되지 않으므로 reload 필수)
    "accounts.google.com",
    "accounts.google.co.kr",
  ]

  private func isGoogleLoginURL(_ url: URL) -> Bool {
    let absolute = url.absoluteString
    return Self.googleLoginURLFragments.contains { absolute.contains($0) }
  }
  
  private func ssoToken(_ url: URL) -> String? {
    return url.queryValue(for: "code")
  }
}


// MARK: - WKNavigationDelegate

extension ESTOneWebViewController: WKNavigationDelegate {
  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    guard let navigatingURL = navigationAction.request.url else {
      decisionHandler(.allow)
      return
    }
    ESTLog.debug("navigation: \(navigatingURL.absoluteString)")

    // 항상 최신 code로 갱신한다. 첫 code 고정 시, 리다이렉트가 중간에 취소되고
    // 재시도 체인이 새 code를 발급받으면(estoneid는 재발급 시 이전 code 무효화)
    // completion에 무효화된 구 code가 전달되어 토큰 발급이 실패한다.
    if let code = ssoToken(navigatingURL) {
      self.ssoToken = code
    }

    // Google OAuth URL → Android UA로 교체 후 cancel→reload.
    // (현재 navigation에는 UA 변경이 적용되지 않으므로 reload 필수.
    //  이미 Android UA면 통과시켜 무한 reload 방지.)
    if isGoogleLoginURL(navigatingURL), webView.customUserAgent != androidUserAgent {
      ESTLog.debug("Google login URL — switching to Android UA & reloading")
      webView.customUserAgent = androidUserAgent
      decisionHandler(.cancel)
      webView.load(URLRequest(url: navigatingURL))
      return
    }

    // callback URL → ssoToken 추출 후 콜백 전달
    if let callbackURL,
       navigatingURL.absoluteString.hasPrefix(callbackURL) {
      ESTLog.debug("callback with ssoToken — completing")
      decisionHandler(.cancel)
      completion?(self.ssoToken)
      return
    }

    // state URL 매칭 → ssoToken 없이 콜백 전달
    if let state = initialState,
       navigatingURL.absoluteString.hasPrefix(state) {
      ESTLog.debug("state url match — completing with url: \(navigatingURL.absoluteString)")
      decisionHandler(.allow)
      completion?(self.ssoToken)
      return
    }

    // non-HTTP 스킴 (tel://, mailto://, sms:// 등) → 시스템에 위임
    if let scheme = navigatingURL.scheme,
       scheme != "http",
       scheme != "https" {
      ESTLog.debug("non-http scheme — delegating to system: \(navigatingURL.absoluteString)")
      UIApplication.shared.open(navigatingURL)
      decisionHandler(.cancel)
      return
    }

    decisionHandler(.allow)
  }

  public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    ESTLog.debug("didStartProvisionalNavigation")
  }

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    ESTLog.debug("didFinish — \(webView.url?.absoluteString ?? "")")
  }

  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    ESTLog.error("didFail — \(error)")
  }

  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    ESTLog.error("didFailProvisionalNavigation — \(error)")
  }
}


// MARK: - WKScriptMessageHandler

extension ESTOneWebViewController: WKScriptMessageHandler {
  public func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {

    guard let action = WebViewMessage(rawValue: message.name) else {
      ESTLog.debug("unknown message — name: \(message.name)")
      return
    }

    switch action {
    case .requestSnsLogin:
      guard let body = message.body as? String,
            let data = body.data(using: .utf8),
            let dto = action.decode(from: data)
      else {
        ESTLog.error("message parse failed — name: \(message.name)")
        return
      }
      handleAction(action, payload: dto)

    case .onLoginComplete:
      // 관찰 전용 — 현재 별도 처리 없음 (dismiss/redirect 미구현)
      break

    case .onPasswordChanged:
      // 비밀번호 변경 통지 → 호스트가 silent 모드로 토큰 재발급 (§7)
      ESTLog.debug("onPasswordChanged")
      onPasswordChanged?()

    case .onAccountDeleted:
      // 회원 탈퇴 통지 → 호스트가 로그아웃 처리 (§7)
      ESTLog.debug("onAccountDeleted")
      onAccountDeleted?()
    }
  }

  private func handleAction(_ action: WebViewMessage, payload: Decodable) {
    switch action {
    case .onLoginComplete, .onPasswordChanged, .onAccountDeleted:
      // userContentController에서 직접 처리됨
      break

    case .requestSnsLogin:
      guard let loginDTO = payload as? RequestLoginDTO,
            let platform = LoginPlatform(rawValue: loginDTO.provider.rawValue)
      else {
        ESTLog.debug("requestSnsLogin — invalid payload")
        return
      }

      ESTLog.debug("requestSnsLogin — provider: \(loginDTO.provider.rawValue)")

      Task {
        do {
          let result = try await ESTLoginManager.shared.login(with: platform)
          ESTLog.info("login success — provider: \(loginDTO.provider.rawValue)")
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
          ESTLog.error("login failed — provider: \(loginDTO.provider.rawValue), error: \(error)")
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
    if case AuthError.cancelled = error { return "cancelled" }
    return "sdk_error"
  }

  @MainActor
  private func sendSuccessResult(_ payload: SNSLoginSuccessPayload) {
    guard let json = payload.jsonString else { return }
    webView?.evaluateJavaScript("window.onNativeSnsLoginResult(\(json))")
  }

  @MainActor
  private func sendErrorResult(_ payload: SNSLoginErrorPayload) {
    guard let json = payload.jsonString else { return }
    ESTLog.error("sendErrorResult — \(json)")
    webView?.evaluateJavaScript("window.onNativeSnsLoginError(\(json))")
  }
}


// MARK: - WKUIDelegate

// Google OAuth는 embedded browser 판정을 위해 JS dialog / window.open 같은
// 표준 브라우저 기능이 살아있는지 본다. uiDelegate 없이 두면 전부 무시돼
// "브라우저 또는 앱이 안전하지 않을 수 있습니다"로 이어질 수 있음.
extension ESTOneWebViewController: WKUIDelegate {
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
