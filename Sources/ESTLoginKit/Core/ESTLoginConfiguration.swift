//
//  ESTLoginConfiguration.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

public struct ESTLoginConfiguration {

  // MARK: - 클라이언트

  let clientId: String

  // MARK: - 카카오

  let kakaoConfig: KakaoConfiguration?


  // MARK: - 네이버

  let naverConfig: NaverConfiguration?

  private init(
    clientId: String,
    kakaoConfig: KakaoConfiguration? = nil,
    naverConfig: NaverConfiguration? = nil
  ) {
    self.clientId = clientId
    self.kakaoConfig = kakaoConfig
    self.naverConfig = naverConfig
  }

  // 빌더 클래스
  public class Builder {
    private var clientId: String

    private var kakaoConfig: KakaoConfiguration?
    private var naverConfig: NaverConfiguration?

    public init(clientId: String) {
      self.clientId = clientId
    }

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
        clientId: clientId,
        kakaoConfig: kakaoConfig,
        naverConfig: naverConfig
      )
    }
  }
}


