//
//  ESTLoginConfiguration.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

public struct ESTLoginConfiguration {
  let kakaoAppKey: String?
  
  private init(
    kakaoAppKey: String? = nil
  ) {
    self.kakaoAppKey = kakaoAppKey
  }
  
  // 빌더 클래스
  public class Builder {
    private var kakaoAppKey: String?
    
    public init() {}
    
    public func useKakao(appKey: String) -> Builder {
      self.kakaoAppKey = appKey
      return self
    }
    
    public func build() -> ESTLoginConfiguration {
      return ESTLoginConfiguration(
        kakaoAppKey: kakaoAppKey
      )
    }
  }
}
