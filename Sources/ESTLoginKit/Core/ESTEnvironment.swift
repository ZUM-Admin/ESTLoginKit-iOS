//
//  ESTEnvironment.swift
//  ESTLoginKit
//
//  통합회원(estoneid) 실행 환경. 환경마다 로그인 웹 host와 API host가 쌍으로 다르므로
//  앱은 환경만 선택하고, SDK가 두 URL을 소유한다(웹/API 불일치 원천 차단).
//

import Foundation

public enum ESTEnvironment {
  case production
  case development
  case test

  /// 로그인/마이페이지 등 웹 화면 base URL.
  var webBaseURL: String {
    switch self {
    case .production:  return "https://estoneid.com"
    case .development: return "https://dev.estoneid.com"
    case .test:        return "https://test.estoneid.com"
    }
  }

  /// 본인인증 등 REST API base URL.
  var apiBaseURL: String {
    switch self {
    case .production:  return "https://api.estoneid.com"
    case .development: return "https://dev-api.estoneid.com"
    case .test:        return "https://test-api.estoneid.com"
    }
  }
}
