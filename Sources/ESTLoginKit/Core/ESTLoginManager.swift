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

  private nonisolated static var configuration: ESTLoginConfiguration? {
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
  
  /// 로그아웃 — best-effort 정리.
  /// 각 단계(네이버/카카오 토큰 삭제, 웹 세션 쿠키 삭제)는 서로 독립적으로 수행되며,
  /// 한 provider의 실패(예: 해당 provider로 로그인하지 않은 상태)가 나머지 정리를 막지 않습니다.
  public func logout() async throws {
    // ① 네이버 — 로컬 토큰 삭제 (실패 시 SDK 내부에서 로깅만 함)
    NidOAuth.shared.logout()

    // ② 카카오 — 로그인 안 된 상태면 에러가 올 수 있으므로 무시하고 진행
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      UserApi.shared.logout { error in
        if let error = error {
          print("[ESTLoginKit] Kakao logout error (ignored): \(error)")
        }
        continuation.resume()
      }
    }

    // ③ 웹 세션 데이터 삭제 — 항상 실행
    await Self.clearWebSession()
  }

  /// estoneid.com 도메인의 WebView 세션 데이터 제거 (로그아웃 시 웹 세션 정리).
  /// 쿠키뿐 아니라 localStorage / sessionStorage / IndexedDB 등 모든 데이터 타입을 제거한다.
  /// (AccountSwitcher의 "바로 로그인" 기억은 쿠키가 아닌 localStorage에 저장될 수 있음)
  @MainActor
  private static func clearWebSession() async {
    let store = WKWebsiteDataStore.default()
    let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
    let records = await store.dataRecords(ofTypes: allTypes)
    let targets = records.filter { $0.displayName.contains("estoneid.com") }
    guard !targets.isEmpty else {
      print("[ESTLoginKit] clearWebSession — no estoneid.com records found")
      return
    }
    print("[ESTLoginKit] clearWebSession — removing \(targets.count) record(s): \(targets.map(\.displayName))")
    await store.removeData(ofTypes: allTypes, for: targets)
  }

  // MARK: - URLs

  private nonisolated static var baseURL: String {
    configuration?.baseURL ?? ESTLoginConfiguration.defaultBaseURL
  }

  public nonisolated var mypageURL: URL {
    URL(string: "\(Self.baseURL)/mypage/setting")!
  }

  /// 로그인 URL을 생성합니다.
  /// - Parameter silent: `true`이면 `silent=true`를 추가해 AccountSwitcher를 건너뛰고
  ///   세션 쿠키가 유효할 때 ssoToken을 자동 발급받습니다. (비밀번호 변경 후 토큰 재발급용, §7.2)
  public nonisolated func loginURL(redirectURL: String? = nil, state: String? = nil, silent: Bool = false) -> URL {
    guard let clientId = Self.configuration?.clientId else {
      fatalError("[ESTLoginKit] loginURL requires initialize() to be called first")
    }
    let base = Self.baseURL
    let actualRedirectURL = redirectURL ?? "\(base)/auth/app-callback"
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
