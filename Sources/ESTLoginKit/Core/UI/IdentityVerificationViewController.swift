//
//  IdentityVerificationViewController.swift
//  ESTLoginKit
//
//  본인인증 진입용 UIKit 컨트롤러.
//

import UIKit
import WebKit

/// 본인인증 화면. (UIKit)
///
/// `IdentityVerificationView`(SwiftUI)와 동일한 동작을 하며, 화면을 띄우고 닫는 것은 호스트 책임입니다.
/// 유효한 accessToken만 넘기면 SDK가 ssoToken 발급 → SSO 부트스트랩 → 본인인증 진입까지 처리하고,
/// 발급 실패 시 `onResult`로 `.failure`가 전달됩니다.
///
/// ```swift
/// let vc = IdentityVerificationViewController(accessToken: accessToken) { [weak self] result in
///   self?.dismiss(animated: true)
///   if case .success(let v) = result { /* v.token으로 세션 재수립 */ }
/// }
/// present(UINavigationController(rootViewController: vc), animated: true)
/// ```
public final class IdentityVerificationViewController: UIViewController {

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

  private var webViewController: ESTOneWebViewController?

  /// 권장 진입점. 유효한 accessToken을 넘기면 열 때마다 ssoToken을 새로 발급해 웹 세션을 수립한다.
  ///
  /// - Parameters:
  ///   - accessToken: 앱이 보유한 유효한 accessToken. 만료 판단·갱신은 앱 책임.
  ///   - callbackURL: 브릿지 미등록 시 리다이렉트될 앱 콜백 URL. 기본값은 `appCallbackURL`.
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
    super.init(nibName: nil, bundle: nil)
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
    super.init(nibName: nil, bundle: nil)
  }

  /// 세션 쿠키가 살아있을 때 URL로 직접 여는 경우. 쿠키가 없으면 로그인 화면이 뜨므로
  /// 일반적으로는 `init(accessToken:)`을 사용하세요.
  ///
  /// - Parameter url: 기본값은 `verificationURL(callbackURL:)`. 직접 넘기면 `callbackURL` 조합을 대체합니다.
  public convenience init(
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

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    switch source {
    case .request(let request):
      embedWebViewController(request: request)

    case .accessToken(let accessToken):
      let spinner = UIActivityIndicatorView(style: .large)
      spinner.center = view.center
      spinner.autoresizingMask = [
        .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin,
      ]
      spinner.startAnimating()
      view.addSubview(spinner)

      Task {
        do {
          let request = try await ESTLoginManager.shared.authorizedVerificationRequest(
            accessToken: accessToken,
            callbackURL: callbackURL
          )
          spinner.removeFromSuperview()
          embedWebViewController(request: request)
        } catch {
          ESTLog.error("verification bootstrap failed — \(error)")
          spinner.removeFromSuperview()
          onResult(.failure(error as? AuthError ?? .unknown(error)))
        }
      }
    }
  }

  private func embedWebViewController(request: URLRequest) {
    let webViewController = ESTOneWebViewController(
      request: request,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onVerificationResult: onResult
    )
    self.webViewController = webViewController

    addChild(webViewController)
    view.addSubview(webViewController.view)
    webViewController.view.frame = view.bounds
    webViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webViewController.didMove(toParent: self)
  }
}
