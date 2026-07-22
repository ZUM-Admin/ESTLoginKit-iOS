//
//  ExampleConfig.swift
//  ESTLoginKit-iOS-Example
//
//  예제 설정값을 Info.plist(← Config.xcconfig)에서 읽는다.
//  시크릿을 소스 코드에 두지 않기 위한 계층으로, 값 교체는 Config.xcconfig만 수정하면 된다.
//

import Foundation

import ESTLoginKit

enum ExampleConfig {
  /// ESTLoginKit 발급 클라이언트 ID (SDK 설정 + 토큰 교환 공통)
  static let clientID = string("ESTClientID")
  /// 토큰 교환용 백엔드 API host (scheme 제외)
  static let apiHost = string("ESTAPIHost")

  static let kakaoAppKey = string("KakaoAppKey")
  static let naverAppName = string("NaverAppName")
  static let naverClientID = string("NaverClientID")
  static let naverClientSecret = string("NaverClientSecret")
  static let naverURLScheme = string("NaverURLScheme")

  /// 실행 환경. Config.xcconfig의 EST_ENVIRONMENT(test|development|production).
  static var environment: ESTEnvironment {
    switch string("ESTEnvironment").lowercased() {
    case "production": return .production
    case "development": return .development
    default: return .test
    }
  }

  private static func string(_ key: String) -> String {
    (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
  }
}
