//
//  ESTLoginManager.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit

import KakaoSDKCommon
import KakaoSDKAuth

public final actor ESTLoginManager {
  public static let shared = ESTLoginManager()
  
  private var configuration: ESTLoginConfiguration?
  
  public func initialize(with config: ESTLoginConfiguration) {
    self.configuration = config
    
    if let kakaoKey = config.kakaoAppKey {
      KakaoSDK.initSDK(appKey: kakaoKey)
    }
  }
  
  public func login(with platform: LoginPlatform) async throws -> String {
    let provider: AuthProvider
    
    switch platform {
    case .kakao:
      provider = KakaoAuthProvider()
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
    
    return false
  }
}
