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
///
/// ```swift
/// let vc = IdentityVerificationViewController { [weak self] result in
///   self?.dismiss(animated: true)
///   if case .success(let v) = result { /* v.token으로 세션 재수립 */ }
/// }
/// present(UINavigationController(rootViewController: vc), animated: true)
/// ```
public final class IdentityVerificationViewController: UIViewController {

  private let webViewController: ESTOneWebViewController

  /// - Parameters:
  ///   - url: 기본값은 `verificationURL(callbackURL:)`. 직접 넘기면 `callbackURL` 조합을 대체합니다.
  ///   - callbackURL: 브릿지 미등록 시 리다이렉트될 앱 콜백 URL. 기본값은 `appCallbackURL`.
  ///   - onResult: 사용자 취소 시 `.failure(.cancelled)`, 승격/병합 실패 시 `.failure(.verificationFailed)`.
  public init(
    url: URL? = nil,
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    onWebViewCreated: ((WKWebView) -> Void)? = nil,
    onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
  ) {
    self.webViewController = ESTOneWebViewController(
      url: url ?? ESTLoginManager.shared.verificationURL(callbackURL: callbackURL),
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      onWebViewCreated: onWebViewCreated,
      onVerificationResult: onResult
    )
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    addChild(webViewController)
    view.addSubview(webViewController.view)
    webViewController.view.frame = view.bounds
    webViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webViewController.didMove(toParent: self)
  }
}
