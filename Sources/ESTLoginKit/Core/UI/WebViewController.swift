//
//  WebViewController.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit
import WebKit

final class WebViewController: UIViewController {
  private let request: URLRequest
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let onWebViewCreated: ((WKWebView) -> Void)?
  private let onPasswordChanged: (() -> Void)?
  private let onAccountDeleted: (() -> Void)?
  private let onVerificationResult: ((Result<VerificationResult, AuthError>) -> Void)?
  private let completion: ((String?) -> Void)?

  // teardown에서 참조를 끊어 순환을 해제하기 위해 var(IUO). Hackle 브릿지가 delegate(self)를 강참조하지만,
  // VC가 webView 참조를 놓으면 webView가 dealloc되며 associated된 브릿지도 사라져 순환이 끊긴다.
  private var webView: WKWebView!
  private var initialState: String?

  private var ssoToken: String?

  // 종료 콜백(로그인 completion / 본인인증 onVerificationResult)은 최초 1회만 호스트에 전달한다.
  // 웹이 리다이렉트를 재시도해 callbackURL이 여러 번 매칭돼도 중복 전달되지 않는다.
  private var hasCompleted = false

  // window.open / target="_blank" 으로 열린 팝업. 중첩 팝업은 지원하지 않고 교체한다.
  private var popupViewController: PopupWebViewController?

  convenience init(
    url: URL,
    callbackURL: String? = nil,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    onVerificationResult: ((Result<VerificationResult, AuthError>) -> Void)? = nil,
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
      onVerificationResult: onVerificationResult,
      completion: completion
    )
  }

  /// SSO 부트스트랩처럼 커스텀 요청으로 첫 화면을 열어야 할 때 사용한다.
  init(
    request: URLRequest,
    callbackURL: String? = nil,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onPasswordChanged: (() -> Void)? = nil,
    onAccountDeleted: (() -> Void)? = nil,
    onVerificationResult: ((Result<VerificationResult, AuthError>) -> Void)? = nil,
    completion: ((String?) -> Void)? = nil
  ) {
    self.request = request
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.onWebViewCreated = onWebViewCreated
    self.onPasswordChanged = onPasswordChanged
    self.onAccountDeleted = onAccountDeleted
    self.onVerificationResult = onVerificationResult
    self.completion = completion
    // 빈 state("?state=")를 허용하면 hasPrefix("")가 항상 true가 되어
    // 첫 네비게이션에서 곧바로 completion이 호출된다.
    self.initialState = Self.resolveInitialState(from: request.url)

    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.default()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true

    // 기본 UA 뒤에 앱 식별 토큰을 append (예: "... zumapp/3.13.3").
    // customUserAgent(전체 교체)와 달리 webView 생성 시점에 박혀서 첫 로드부터 적용되고,
    // navigator.userAgent를 비동기로 읽어 붙일 필요가 없다.
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

  override func viewDidLoad() {
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

    self.webView.load(self.request)
  }

  private func setupLayout() {
    self.view.addSubview(self.webView)
    self.webView.frame = self.view.frame
  }

  /// 메시지 핸들러/델리게이트/로딩을 정리해 누수를 막는다.
  /// SwiftUI 경로는 `dismantleUIViewController`에서 자동 호출한다.
  /// UIKit에서 이 컨트롤러를 직접 present/push해 쓰는 경우, `onWebViewCreated`로
  /// webView를 강참조하는 브릿지(예: Hackle)를 붙였다면 화면을 닫을 때 직접 호출해 순환을 끊어야 한다.
  func teardown() {
    dismissPopup(animated: false)
    WebViewMessage.allCases.forEach {
      webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
    }
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
    webView.removeFromSuperview()
    webView = nil  // VC의 강참조 해제 → webView(+associated Hackle 브릿지) dealloc → 순환 끊김
  }
  private func ssoToken(_ url: URL) -> String? {
    // 부트스트랩 URL(/auth/sso-login)의 code는 웹 세션 수립용 1회성 토큰이라
    // 로그인 완료 code로 수집하면 안 된다. (completion에 소진된 토큰이 전달됨)
    guard url.path != "/auth/sso-login" else { return nil }
    return url.nonEmptyQueryValue(for: "code")
  }

  /// 로그인 완료 감지(state 매칭)의 대상 state를 요청 URL에서 추출한다.
  /// 1) top-level `state` — `/user/login?...&state=` 직접 진입
  /// 2) 없으면 부트스트랩(`/auth/sso-login?redirect_url=<.../user/login?...&state=...>`)의
  ///    `redirect_url` 안쪽 `state` — 부트스트랩 진입 시 호스트가 top-level state를
  ///    중복으로 싣지 않아도 완료를 감지할 수 있게 한다.
  private static func resolveInitialState(from url: URL?) -> String? {
    guard let url else { return nil }
    if let top = url.nonEmptyQueryValue(for: "state") { return top }
    guard let redirect = url.nonEmptyQueryValue(for: "redirect_url"),
          let inner = URLComponents(string: redirect),
          let nested = inner.queryItems?.first(where: { $0.name == "state" })?.value,
          !nested.isEmpty
    else { return nil }
    return nested
  }

  // MARK: - Identity Verification

  /// 본인인증 완료 통지를 호스트에 1회만 전달한다. (`callbackURL` 리다이렉트로만 도착한다)
  private func deliverVerificationResult(status: String?, token: String?) {
    guard !hasCompleted else {
      ESTLog.debug("verification result already delivered — ignoring")
      return
    }
    hasCompleted = true
    dismissPopup(animated: false)
    onVerificationResult?(VerificationCompleteStatus.result(status: status, token: token))
  }

  /// 로그인 완료(ssoToken 또는 nil)를 호스트에 1회만 전달한다. (callbackURL/state 매칭 중 먼저 도착한 쪽)
  private func finishLogin(_ ssoToken: String?) {
    guard !hasCompleted else {
      ESTLog.debug("login completion already delivered — ignoring")
      return
    }
    hasCompleted = true
    // 팝업 안에서 로그인이 끝날 수 있다(외부 IdP). 호스트가 화면을 닫기 전에 팝업부터 내린다.
    dismissPopup(animated: false)
    completion?(ssoToken)
  }

  // MARK: - Popup

  /// JS 다이얼로그는 최상단에서 띄워야 한다. 이미 present 중인 VC 에서 present 하면 iOS 가 무시한다.
  private var dialogPresenter: UIViewController { popupViewController ?? self }

  private func showPopup(_ controller: PopupWebViewController) {
    let present = { [weak self] in
      guard let self else { return }
      self.present(controller, animated: true)
      controller.presentationController?.delegate = self
    }

    // 교체 시에는 dismiss 완료 후 present 해야 한다. 같은 런루프에서 겹치면 present 가 유실된다.
    if let existing = popupViewController {
      popupViewController = nil
      existing.teardownWebView()
      existing.dismiss(animated: false) { present() }
    } else {
      present()
    }
    popupViewController = controller
  }

  private func dismissPopup(animated: Bool) {
    guard let popup = popupViewController else { return }
    popupViewController = nil
    popup.teardownWebView()
    popup.dismiss(animated: animated)
    ESTLog.debug("popup closed")
  }
}


// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    guard let navigatingURL = navigationAction.request.url else {
      decisionHandler(.allow)
      return
    }
    let scope = (webView === popupViewController?.webView) ? "popup " : ""
    ESTLog.debug("\(scope)navigation: \(navigatingURL.redactedForLog)")

    // 항상 최신 code로 갱신한다. 첫 code 고정 시, 리다이렉트가 중간에 취소되고
    // 재시도 체인이 새 code를 발급받으면(estoneid는 재발급 시 이전 code 무효화)
    // completion에 무효화된 구 code가 전달되어 토큰 발급이 실패한다.
    if let code = ssoToken(navigatingURL) {
      self.ssoToken = code
    }

    // 구글 OAuth 용 UA 스왑은 **의도적으로 없다.**
    //
    // 예전엔 여기서 accounts.google.com 을 감지해 하드코딩된 Android Chrome UA 로 갈아끼우고
    // cancel→reload 했다. 그런데 그 UA(Chrome 137)가 낡아서 구글이 오히려 차단하기 시작했다 —
    // "브라우저 또는 앱이 안전하지 않을 수 있습니다" 로 로그인 자체가 막혔다.
    //
    // 실측 결과 WKWebView 기본 UA 로는 정상 통과한다.
    //   Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X)
    //   AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148
    // Android 도 동일하게 기본 UA(`; wv` 포함)로 통과하는 것을 확인하고 스왑을 제거했다.
    //
    // 기기·OS 를 위장하는 하드코딩 UA 는 시간이 지나면 반드시 낡아 같은 사고를 반복한다.
    // 구글이 정책을 조여 다시 차단하기 시작하면, 문자열을 새로 지어내지 말고 **실제 UA 에서
    // 문제되는 토큰만 제거**하는 방식으로 접근하라. 앱 식별용 토큰은
    // `applicationNameForUserAgent` 로 웹뷰 생성 시점에 이미 붙는다.

    // callback URL → ssoToken 추출 후 콜백 전달
    if let callbackURL,
       navigatingURL.absoluteString.hasPrefix(callbackURL) {
      decisionHandler(.cancel)

      // 본인인증 완료는 이 리다이렉트로만 통지된다(?status=...&code=<ssoToken>).
      if onVerificationResult != nil {
        ESTLog.debug("verification callback — completing")
        deliverVerificationResult(
          status: navigatingURL.nonEmptyQueryValue(for: "status"),
          token: self.ssoToken
        )
        return
      }

      ESTLog.debug("callback with ssoToken — completing")
      finishLogin(self.ssoToken)
      return
    }

    // state URL 매칭 → ssoToken 없이 콜백 전달
    if let state = initialState,
       navigatingURL.absoluteString.hasPrefix(state) {
      ESTLog.debug("state url match — completing with url: \(navigatingURL.absoluteString)")
      decisionHandler(.allow)
      finishLogin(self.ssoToken)
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

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    ESTLog.debug("didStartProvisionalNavigation")
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    ESTLog.debug("didFinish — \(webView.url?.redactedForLog ?? "")")
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    ESTLog.error("didFail — \(error)")
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    ESTLog.error("didFailProvisionalNavigation — \(error)")
  }
}


// MARK: - WKScriptMessageHandler

extension WebViewController: WKScriptMessageHandler {
  func userContentController(
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

    case .requestLogout:
      // "다른 계정으로 로그인" 등 — 웹이 네이티브 SNS SDK에 캐싱된 로그인 상태를 지워달라고 요청.
      // 이게 없으면 다음 requestSnsLogin에서 카카오/네이버 SDK가 기존 토큰을 재사용해
      // 계정 선택창 없이 같은 계정으로 조용히 로그인된다.
      // 웹 세션 쿠키와 호스트 토큰은 건드리지 않는다(각자 책임).
      ESTLog.debug("requestLogout")
      Task { await ESTLoginManager.shared.logout() }

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
    case .requestLogout, .onLoginComplete, .onPasswordChanged, .onAccountDeleted:
      // userContentController에서 직접 처리됨
      break

    case .requestSnsLogin:
      guard let loginDTO = payload as? SNSLoginRequestPayload else {
        ESTLog.debug("requestSnsLogin — invalid payload")
        return
      }

      let provider = loginDTO.provider

      // 구글/애플 등은 네이티브 미지원 → 웹 OAuth 경로를 써야 한다.
      // 조용히 리턴하면 웹이 콜백을 무한정 기다리므로 반드시 에러로 통지한다. (Android와 동일)
      guard let platform = loginDTO.platform else {
        ESTLog.debug("requestSnsLogin — unsupported provider: \(provider)")
        sendErrorResult(
          SNSLoginErrorPayload(
            code: "unsupported_provider",
            message: "\(provider) native login is not supported. Use WebView OAuth path.",
            provider: provider
          )
        )
        return
      }

      ESTLog.debug("requestSnsLogin — provider: \(provider)")

      Task {
        do {
          let result = try await ESTLoginManager.shared.login(with: platform)
          ESTLog.info("login success — provider: \(provider)")
          sendSuccessResult(
            SNSLoginSuccessPayload(
              provider: provider,
              authorizeToken: result.authorizeToken,
              refreshToken: result.refreshToken,
              ci: result.ci,
              email: result.email
            )
          )
        } catch {
          ESTLog.error("login failed — provider: \(provider), error: \(error)")
          sendErrorResult(
            SNSLoginErrorPayload(
              code: errorCode(from: error),
              message: error.localizedDescription,
              provider: provider
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
    webView?.evaluateJavaScript(Self.callbackScript("onNativeSnsLoginResult", json))
  }

  @MainActor
  private func sendErrorResult(_ payload: SNSLoginErrorPayload) {
    guard let json = payload.jsonString else { return }
    ESTLog.error("sendErrorResult — \(json)")
    webView?.evaluateJavaScript(Self.callbackScript("onNativeSnsLoginError", json))
  }

  /// 웹이 콜백을 아직 정의하지 않았을 때 JS 예외로 죽지 않고 경고만 남기도록 감싼다.
  /// (Android `SnsLoginBridge.callbackScript` 와 동일한 형태)
  private static func callbackScript(_ functionName: String, _ payload: String) -> String {
    """
    (function() {
      if (typeof window.\(functionName) === "function") {
        window.\(functionName)(\(payload));
      } else {
        console.warn("Missing window.\(functionName)");
      }
    })();
    """
  }
}


// MARK: - WKUIDelegate

// Google OAuth는 embedded browser 판정을 위해 JS dialog / window.open 같은
// 표준 브라우저 기능이 살아있는지 본다. uiDelegate 없이 두면 전부 무시돼
// "브라우저 또는 앱이 안전하지 않을 수 있습니다"로 이어질 수 있음.
extension WebViewController: WKUIDelegate {
  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    // 팝업을 부모 webView 에 로드해버리면 window.open() 이 null 을 반환해 opener 기반 플로우가
    // 죽고, 빈 창(window.open(''))이면 부모가 about:blank 로 덮여 화면이 하얘진다.
    // 외부 IdP 로 넘어가는 로그인이 이 경로를 탄다. → 실제 팝업 화면을 띄운다.

    // 반드시 전달받은 configuration 으로 만들어야 opener 관계(window.opener / postMessage)가 산다.
    let popup = WKWebView(frame: .zero, configuration: configuration)
    popup.navigationDelegate = self
    popup.uiDelegate = self
    popup.allowsBackForwardNavigationGestures = true
    // 팝업에서 다시 구글로 가는 경우를 위해 UA 우회를 승계한다.
    popup.customUserAgent = webView.customUserAgent
    if #available(iOS 16.4, *) {
      popup.isInspectable = inspectable
    }

    guard viewIfLoaded?.window != nil else {
      // 화면에 붙기 전이면 present 할 수 없다. 부모에서 여는 기존 폴백으로 되돌린다.
      ESTLog.debug("popup: not in window — falling back to parent load")
      if let url = navigationAction.request.url {
        webView.load(URLRequest(url: url))
      }
      return nil
    }

    ESTLog.debug("popup opened — \(navigationAction.request.url?.redactedForLog ?? "about:blank")")
    showPopup(PopupWebViewController(webView: popup) { [weak self] in
      self?.dismissPopup(animated: true)
    })

    // 요청 로드는 WebKit 이 반환된 webView 에 직접 수행한다. 여기서 load 하면 이중 로드가 된다.
    return popup
  }

  /// 웹의 `window.close()` — 외부 IdP 인증을 마친 팝업이 스스로 닫는 경로.
  func webViewDidClose(_ webView: WKWebView) {
    guard popupViewController?.webView === webView else { return }
    ESTLog.debug("popup requested close (window.close)")
    dismissPopup(animated: true)
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> Void
  ) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
    dialogPresenter.present(alert, animated: true)
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (Bool) -> Void
  ) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
    alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
    dialogPresenter.present(alert, animated: true)
  }

  func webView(
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
    dialogPresenter.present(alert, animated: true)
  }
}


// MARK: - UIAdaptivePresentationControllerDelegate

extension WebViewController: UIAdaptivePresentationControllerDelegate {
  /// 사용자가 팝업을 아래로 쓸어내려 닫은 경우 — 참조를 놓고 WebView 를 정리한다.
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let popup = popupViewController,
          presentationController.presentedViewController === popup
    else { return }
    popupViewController = nil
    popup.teardownWebView()
    ESTLog.debug("popup dismissed by user")
  }
}
