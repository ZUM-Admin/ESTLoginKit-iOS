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

  private let webView: WKWebView

  public init(
    url: URL,
    externalUserAgent: String? = nil
  ) {
    self.url = url
    self.externalUserAgent = externalUserAgent
    let config = WKWebViewConfiguration()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true

    let webView = WKWebView(frame: CGRect.zero, configuration: config)
    webView.allowsBackForwardNavigationGestures = true
    self.webView = webView
    super.init(nibName: nil, bundle: nil)
    print("[LoginWebViewController] init — url: \(url)")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("[LoginWebViewController] viewWillAppear — registering message handlers")

    WebViewMessage.allCases.forEach { message in
      self.webView.configuration.userContentController
        .removeScriptMessageHandler(
          forName: message.rawValue
        )

      self.webView.configuration.userContentController.add(
        LeakAvoider(delegate: self),
        name: message.rawValue
      )
      print("[LoginWebViewController] registered handler: \(message.rawValue)")
    }
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupLayout()
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
}


// MARK: - WKNavigationDelegate

extension LoginWebViewController: WKNavigationDelegate {
  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    let url = navigationAction.request.url?.absoluteString ?? "unknown"
    print("[LoginWebViewController] navigation: \(url)")
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
          let token = try await ESTLoginManager.shared.login(with: platform)
          print("[LoginWebViewController] login success — provider: \(loginDTO.provider.rawValue), token: \(token.prefix(20))...")
          sendSuccessResult(
            SNSLoginSuccessPayload(
              provider: loginDTO.provider.rawValue,
              authorizeToken: token,
              refreshToken: "",
              ci: "",
              email: ""
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
