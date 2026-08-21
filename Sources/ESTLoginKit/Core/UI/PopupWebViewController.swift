//
//  PopupWebViewController.swift
//  ESTLoginKit
//

import UIKit
import WebKit

/// `window.open` / `target="_blank"` 으로 열린 팝업 WebView 를 별도 화면으로 호스팅한다.
///
/// 팝업을 부모 WebView 에 그냥 로드해버리면(이전 동작) 두 가지가 깨진다.
/// 1. `createWebViewWith` 가 nil 을 반환하므로 웹의 `window.open()` 이 항상 null →
///    `w.location` / `w.postMessage` 같은 opener 기반 코드가 그 줄에서 죽는다
/// 2. 빈 창(`window.open('')`)이면 부모가 about:blank 로 덮여 화면이 하얘진다
///
/// 외부 IdP 로 넘어가는 로그인(Apple 회사계정 등)이 이 경로를 탄다.
/// Android `WebViewPopupHost` 와 대칭.
final class PopupWebViewController: UIViewController {

  let webView: WKWebView

  /// 시트로 present 되면 safe area 상단이 카드 모서리와 맞붙어 바가 답답해 보인다. 그만큼 띄운다.
  private let inset: CGFloat = 8

  private let onClose: () -> Void
  private let hostLabel = UILabel()
  private var urlObservation: NSKeyValueObservation?

  init(webView: WKWebView, onClose: @escaping () -> Void) {
    self.webView = webView
    self.onClose = onClose
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    urlObservation?.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let bar = UIView()
    bar.backgroundColor = .systemBackground

    // window.close() 를 부르지 않는 페이지도 빠져나올 수 있어야 한다.
    let closeButton = UIButton(type: .system)
    closeButton.setTitle("닫기", for: .normal)
    closeButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
    closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

    // 팝업엔 주소창이 없다. 자격증명을 입력하는 도메인은 사용자에게 보여야 한다.
    hostLabel.font = .preferredFont(forTextStyle: .footnote)
    hostLabel.textColor = .secondaryLabel
    hostLabel.textAlignment = .center
    hostLabel.lineBreakMode = .byTruncatingMiddle

    let separator = UIView()
    separator.backgroundColor = .separator

    for subview in [bar, webView] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(subview)
    }
    for subview in [closeButton, hostLabel, separator] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      bar.addSubview(subview)
    }

    let hairline = 1 / max(view.traitCollection.displayScale, 1)

    NSLayoutConstraint.activate([
      bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: inset),
      bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
      bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bar.heightAnchor.constraint(equalToConstant: 48),

      closeButton.leadingAnchor.constraint(equalTo: bar.layoutMarginsGuide.leadingAnchor),
      closeButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

      hostLabel.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
      hostLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
      hostLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
      hostLabel.trailingAnchor.constraint(lessThanOrEqualTo: bar.layoutMarginsGuide.trailingAnchor),

      separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
      separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: hairline),

      webView.topAnchor.constraint(equalTo: bar.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    urlObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
      self?.hostLabel.text = webView.url?.host
    }
  }

  @objc private func closeTapped() {
    onClose()
  }

  /// 팝업 WebView 의 로딩/델리게이트를 끊는다.
  ///
  /// 메시지 핸들러는 제거하지 않는다 — 팝업은 부모의 `WKUserContentController` 를 그대로
  /// 공유(opener 관계 유지에 필요)하므로, 여기서 지우면 부모 웹뷰의 JS 브릿지까지 죽는다.
  func teardownWebView() {
    urlObservation?.invalidate()
    urlObservation = nil
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
  }
}
