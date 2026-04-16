//
//  ESTLoginManager.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit

import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

import NidThirdPartyLogin

public final actor ESTLoginManager {
  public static let shared = ESTLoginManager()
  
  private var configuration: ESTLoginConfiguration?
  
  public func initialize(with config: ESTLoginConfiguration) {
    self.configuration = config
    
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
  
  public func logout() async throws {
    NidOAuth.shared.logout()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      UserApi.shared.logout { error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  // MARK: - URLs

  private var baseURL: String {
    configuration?.baseURL ?? ESTLoginConfiguration.defaultBaseURL
  }

  public var mypageURL: URL {
    URL(string: "\(baseURL)/mypage/setting")!
  }

  public func loginURL(redirectURL: String? = nil, state: String? = nil) -> URL {
    guard let clientId = configuration?.clientId else {
      fatalError("[ESTLoginKit] loginURL requires initialize() to be called first")
    }
    let base = baseURL
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
