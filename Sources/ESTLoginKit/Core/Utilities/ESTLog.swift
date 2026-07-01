//
//  ESTLog.swift
//  ESTLoginKit
//
//  ESTLoginKit 공통 로거. SDK의 모든 로그는 이걸로 찍는다(print 금지).
//  os.Logger 기반이라 print보다 가볍고, debug 레벨은 Release에서 자동 제외된다.
//
//  규칙
//  - 모든 라인은 `[ESTLoginKit]` 로 묶인다(접두사 자동).
//  - 레벨: debug(상세 흐름/통신) · info(주요 이벤트) · error(실패/에러).
//  - 민감정보(accessToken/refreshToken/비밀번호 등)는 로그에 넣지 않는다.
//    값은 `.public`으로 노출되므로 시스템 로그에 남는다.
//  - 메시지는 `동작: 값` 형태로 간결하게.
//

import os

enum ESTLog {
  private static let logger = Logger(subsystem: "com.estaid.ESTLoginKit", category: "ESTLoginKit")

  /// 상세 흐름/통신. Release 빌드에서는 저장/출력되지 않는다.
  static func debug(_ message: String) {
    logger.debug("[ESTLoginKit] \(message, privacy: .public)")
  }

  /// 주요 이벤트(로그인 성공 등).
  static func info(_ message: String) {
    logger.info("[ESTLoginKit] \(message, privacy: .public)")
  }

  /// 실패/에러.
  static func error(_ message: String) {
    logger.error("[ESTLoginKit] \(message, privacy: .public)")
  }
}
