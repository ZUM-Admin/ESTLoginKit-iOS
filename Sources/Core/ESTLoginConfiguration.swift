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
  
  private init(
    kakaoConfig: KakaoConfiguration? = nil,
    naverConfig: NaverConfiguration? = nil
  ) {
    self.kakaoConfig = kakaoConfig
    self.naverConfig = naverConfig
  }
  
  // 빌더 클래스
  public class Builder {
    private var kakaoConfig: KakaoConfiguration?
    private var naverConfig: NaverConfiguration?
    
    public init() {}
    
    public func useKakao(_ config: KakaoConfiguration?) -> Builder {
      self.kakaoConfig = config
      return self
    }
    
    public func useNaver(_ config: NaverConfiguration?) -> Builder {
      self.naverConfig = config
      return self
    }
    
    public func build() -> ESTLoginConfiguration {
      return ESTLoginConfiguration(
        kakaoConfig: kakaoConfig,
        naverConfig: naverConfig
      )
    }
  }
}


