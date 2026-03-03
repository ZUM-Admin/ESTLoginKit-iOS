//
//  ESTLoginManager.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit

import KakaoSDKCommon
import KakaoSDKAuth

import NidThirdPartyLogin

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
  
  public func login(with platform: LoginPlatform) async throws -> String {
    let provider: AuthProvider
    
    switch platform {
    case .kakao:
      provider = KakaoAuthProvider()
      
    case .naver:
      provider = NaverAuthProvider()
    default:
      throw AuthError.unsupportedPlatform
    }
    
    return try await provider.login()
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
