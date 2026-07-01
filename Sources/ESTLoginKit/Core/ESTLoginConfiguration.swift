//
//  ESTLoginConfiguration.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

public struct ESTLoginConfiguration {

  public static let defaultBaseURL = "https://estoneid.com"

  // MARK: - 클라이언트

  let clientId: String

  // MARK: - 환경

  let environment: ESTEnvironment

  // MARK: - 카카오

  let kakaoConfig: KakaoConfiguration?


  // MARK: - 네이버

  let naverConfig: NaverConfiguration?

  // MARK: - 파생 URL (환경 소유)

  /// 로그인/마이페이지 웹 base URL.
  var baseURL: String { environment.webBaseURL }
  /// 본인인증 등 REST API base URL.
  var apiBaseURL: String { environment.apiBaseURL }

  private init(
    clientId: String,
    environment: ESTEnvironment,
    kakaoConfig: KakaoConfiguration? = nil,
    naverConfig: NaverConfiguration? = nil
  ) {
    self.clientId = clientId
    self.environment = environment
    self.kakaoConfig = kakaoConfig
    self.naverConfig = naverConfig
  }

  // 빌더 클래스
  public class Builder {
    private var clientId: String
    private var environment: ESTEnvironment = .production

    private var kakaoConfig: KakaoConfiguration?
    private var naverConfig: NaverConfiguration?

    public init(clientId: String) {
      self.clientId = clientId
    }

    /// 실행 환경 선택. 웹/API base URL이 함께 결정된다. (기본: `.production`)
    public func useEnvironment(_ environment: ESTEnvironment) -> Builder {
      self.environment = environment
      return self
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
        environment: environment,
        kakaoConfig: kakaoConfig,
        naverConfig: naverConfig
      )
    }
  }
}
