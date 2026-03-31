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
import GoogleSignIn

public final actor ESTLoginManager {
  public static let shared = ESTLoginManager()
  
  private var configuration: ESTLoginConfiguration?
  
  public func initialize(with config: ESTLoginConfiguration) {
    self.configuration = config
    
    if let kakaoConfig = config.kakaoConfig {
      KakaoSDK.initSDK(appKey: kakaoConfig.appKey)
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

    case .google:
      provider = GoogleAuthProvider()

    case .apple:
      provider = AppleAuthProvider()

    default:
      throw AuthError.unsupportedPlatform
    }
    
    return try await provider.login()
  }
  
  public func logout() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      UserApi.shared.logout { error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
    NidOAuth.shared.logout()
  }

  @MainActor
  public func handle(_ url: URL) -> Bool {
    if AuthApi.isKakaoTalkLoginUrl(url) {
      return AuthController.handleOpenUrl(url: url)
    }
    
    if NidOAuth.shared.handleURL(url) == true {
      return true
    }

    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }

    return false
  }
}
