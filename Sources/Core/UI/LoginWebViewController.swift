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
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    WebViewMessage.allCases.forEach { message in
      self.webView.configuration.userContentController
        .removeScriptMessageHandler(
          forName: message.rawValue
        )
      
      self.webView.configuration.userContentController.add(
        LeakAvoider(delegate: self),
        name: message.rawValue
      )
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
    decisionHandler(.allow)
  }
}


// MARK: - WKScriptMessageHandler

extension LoginWebViewController: WKScriptMessageHandler {
  public func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard let action = WebViewMessage(rawValue: message.name),
          let body = message.body as? String,
          let data = body.data(using: .utf8),
          let dto = action.decode(from: data)
    else {
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
        return
      }

      Task {
        do {
          let token = try await ESTLoginManager.shared.login(with: platform)
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
    webView.evaluateJavaScript("window.onNativeSnsLoginResult(\(json))")
  }

  @MainActor
  private func sendErrorResult(_ payload: SNSLoginErrorPayload) {
    guard let json = payload.jsonString else { return }
    webView.evaluateJavaScript("window.onNativeSnsLoginError(\(json))")
  }
}


