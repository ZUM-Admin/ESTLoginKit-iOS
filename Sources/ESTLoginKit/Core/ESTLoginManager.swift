//
//  ESTLoginManager.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit
import WebKit

import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

import NidThirdPartyLogin

public final actor ESTLoginManager {
  public static let shared = ESTLoginManager()

  // 설정은 initialize()에서 1회 설정되며, URL 생성을 위해 동기적으로(nonisolated) 읽힌다.
  private nonisolated(unsafe) static var _configuration: ESTLoginConfiguration?
  private nonisolated static let configurationLock = NSLock()

  nonisolated static var configuration: ESTLoginConfiguration? {
    get {
      configurationLock.lock(); defer { configurationLock.unlock() }
      return _configuration
    }
    set {
      configurationLock.lock(); defer { configurationLock.unlock() }
      _configuration = newValue
    }
  }

  public func initialize(with config: ESTLoginConfiguration) {
    Self.configuration = config

    if let kakaoConfig = config.kakaoConfig {
      KakaoSDK.initSDK(appKey: kakaoConfig.appKey, customScheme: kakaoConfig.customScheme)
    }
    
    if let naverConfig = config.naverConfig {
      NidOAuth.shared.initialize(
        appName: naverConfig.appName,
        clientId: naverConfig.clientID,
        clientSecret: naverConfig.clientSecret,
        urlScheme: naverConfig.urlScheme
      )
    }
  }
  
  public func login(with platform: LoginPlatform) async throws -> AuthResult {
    let provider: AuthProvider
    
    switch platform {
    case .kakao:
      provider = KakaoAuthProvider()

    case .naver:
      provider = NaverAuthProvider()
    }
    
    return try await provider.login()
  }
  
  /// 로그아웃 — 네이티브 SDK 토큰 정리 (best-effort).
  /// 각 단계는 서로 독립적으로 수행되며, 한 provider의 실패(예: 해당 provider로 로그인하지
  /// 않은 상태)가 나머지 정리를 막지 않습니다.
  ///
  /// 웹 세션(쿠키/스토리지)은 SDK가 건드리지 않습니다 — 웹 세션은 웹이 소유하며,
  /// est 웹뷰는 열 때마다 accessToken 부트스트랩으로 세션을 새로 검증·수립하므로
  /// 앱 로그아웃 시 로컬 웹 데이터를 지울 필요가 없습니다.
  /// (앱이 저장한 accessToken/refreshToken 삭제는 호스트 책임)
  public func logout() async throws {
    // ① 네이버 — 로컬 토큰 삭제 (실패 시 SDK 내부에서 로깅만 함)
    NidOAuth.shared.logout()

    // ② 카카오 — 로그인 안 된 상태면 에러가 올 수 있으므로 무시하고 진행
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      UserApi.shared.logout { error in
        if let error = error {
          ESTLog.error("Kakao logout error (ignored): \(error)")
        }
        continuation.resume()
      }
    }
  }

  // MARK: - URLs

  nonisolated static var baseURL: String {
    configuration?.baseURL ?? ESTLoginConfiguration.defaultBaseURL
  }

  public nonisolated var mypageURL: URL {
    URL(string: "\(Self.baseURL)/mypage/setting")!
  }

  /// 앱 콜백 기본 URL. `loginURL()`의 redirect_url 기본값이자,
  /// `LoginWebView`/`IdentityVerificationView` 등의 `callbackURL` 기본값으로 사용된다.
  public nonisolated var appCallbackURL: String {
    "\(Self.baseURL)/auth/app-callback"
  }

  /// 로그인 URL을 생성합니다.
  /// - Parameter silent: `true`이면 `silent=true`를 추가해 AccountSwitcher를 건너뛰고
  ///   세션 쿠키가 유효할 때 ssoToken을 자동 발급받습니다. (비밀번호 변경 후 토큰 재발급용, §7.2)
  public nonisolated func loginURL(redirectURL: String? = nil, state: String? = nil, silent: Bool = false) -> URL {
    guard let clientId = Self.configuration?.clientId else {
      fatalError("[ESTLoginKit] loginURL requires initialize() to be called first")
    }
    let base = Self.baseURL
    let actualRedirectURL = redirectURL ?? appCallbackURL
    var components = URLComponents(string: "\(base)/user/login")!
    var items = [
      URLQueryItem(name: "type", value: "callback"),
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "redirect_url", value: actualRedirectURL),
    ]
    if let state {
      items.append(URLQueryItem(name: "state", value: state))
    }
    if silent {
      items.append(URLQueryItem(name: "silent", value: "true"))
    }
    components.queryItems = items
    return components.url!
  }

  /// 본인인증 화면 URL을 생성합니다.
  ///
  /// 웹뷰가 임시 회원의 로그인 세션 쿠키를 갖고 있어야 하며, 인증 회원 승격과 CI 충돌 해소는
  /// 웹뷰가 자체 처리합니다. 완료 통지는 브릿지(`onVerificationComplete`)가 우선이고,
  /// 브릿지가 없을 때만 `callbackURL`로 리다이렉트되므로 둘 중 하나만 처리하면 됩니다.
  ///
  /// - Parameter callbackURL: 브릿지 미등록 시 리다이렉트될 앱 콜백 URL. (선택)
  public nonisolated func verificationURL(callbackURL: String? = nil) -> URL {
    guard let clientId = Self.configuration?.clientId else {
      fatalError("[ESTLoginKit] verificationURL requires initialize() to be called first")
    }
    var components = URLComponents(string: "\(Self.baseURL)/webview/verification")!
    var items = [URLQueryItem(name: "client_id", value: clientId)]
    if let callbackURL {
      items.append(URLQueryItem(name: "callbackURL", value: callbackURL))
    }
    components.queryItems = items
    return components.url!
  }

  @MainActor
  public func handle(_ url: URL) -> Bool {
    if AuthApi.isKakaoTalkLoginUrl(url) {
      return AuthController.handleOpenUrl(url: url)
    }
    
    if NidOAuth.shared.handleURL(url) == true {
      return true
    }

    return false
  }
}
