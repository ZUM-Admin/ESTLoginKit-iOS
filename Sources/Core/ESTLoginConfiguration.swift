//
//  ESTLoginConfiguration.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

public struct ESTLoginConfiguration {
  
  
  // MARK: - 카카오
  
  let kakaoConfig: KakaoConfiguration?
  
  
  // MARK: - 네이버

  let naverConfig: NaverConfiguration?


  // MARK: - 구글
  // Google Sign-In은 앱 타겟 Info.plist의 GIDClientID를 자동으로 읽으므로
  // 별도 설정 모델 없이 useGoogle() 호출만으로 활성화됩니다.

  let isGoogleEnabled: Bool

  private init(
    kakaoConfig: KakaoConfiguration? = nil,
    naverConfig: NaverConfiguration? = nil,
    isGoogleEnabled: Bool = false
  ) {
    self.kakaoConfig = kakaoConfig
    self.naverConfig = naverConfig
    self.isGoogleEnabled = isGoogleEnabled
  }

  // 빌더 클래스
  public class Builder {
    private var kakaoConfig: KakaoConfiguration?
    private var naverConfig: NaverConfiguration?
    private var isGoogleEnabled: Bool = false

    public init() {}

    public func useKakao(_ config: KakaoConfiguration?) -> Builder {
      self.kakaoConfig = config
      return self
    }

    public func useNaver(_ config: NaverConfiguration?) -> Builder {
      self.naverConfig = config
      return self
    }

    public func useGoogle() -> Builder {
      self.isGoogleEnabled = true
      return self
    }

    public func build() -> ESTLoginConfiguration {
      return ESTLoginConfiguration(
        kakaoConfig: kakaoConfig,
        naverConfig: naverConfig,
        isGoogleEnabled: isGoogleEnabled
      )
    }
  }
}


