//
//  AuthError.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

public enum AuthError: Error {
  case unsupportedPlatform
  case cancelled
  /// initialize(with:)가 호출되지 않아 설정(환경/clientId)이 없음.
  case notInitialized
  /// 본인인증 승격/병합 실패, 또는 완료 통지를 해석할 수 없음.
  case verificationFailed
  /// 서버가 2xx가 아닌 상태 코드로 응답.
  case server(statusCode: Int)
  case unknown(Error?)
}

