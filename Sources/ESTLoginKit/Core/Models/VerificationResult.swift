//
//  VerificationResult.swift
//  ESTLoginKit
//
//  본인인증 화면의 완료 결과.
//

import Foundation

/// 본인인증 화면이 `certified`로 완료됐을 때 전달되는 결과.
public struct VerificationResult {
  /// 본인인증 후 재발급된 ssoToken.
  ///
  /// CI 충돌로 계정이 병합되면 웹뷰 안의 세션이 다른 계정으로 바뀌어 있을 수 있다.
  /// 호스트는 이 토큰으로 세션을 재수립해야 병합된 계정과 상태가 맞는다.
  public let token: String
}
