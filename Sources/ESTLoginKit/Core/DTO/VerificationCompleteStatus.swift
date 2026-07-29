//
//  VerificationCompletePayload.swift
//  ESTLoginKit
//
//  본인인증 완료 통지 페이로드.
//  브릿지(`onVerificationComplete`)와 callbackURL 리다이렉트가 같은 status 값을 쓴다.
//

import Foundation

/// `{ "status": "certified", "token": "<ssoToken, certified일 때만>" }`
struct VerificationCompletePayload: Decodable {
  /// 문서에 없는 값이 와도 디코딩을 깨뜨리지 않도록 String으로 받고 매핑 시점에 해석한다.
  let status: String
  let token: String?
}

/// 본인인증 종료 상태. callbackURL에서는 `?status=`, 브릿지에서는 payload의 `status`로 전달된다.
enum VerificationCompleteStatus: String {
  /// 승격 완료 (CI 충돌 시 계정 병합까지 완료)
  case certified
  /// 사용자가 본인인증을 취소/중단
  case cancelled
  /// 승격 실패, 병합 실패, cert 조회 실패 등
  case error

  /// 브릿지/callbackURL 어느 경로로 들어왔든 동일하게 호스트 결과로 해석한다.
  /// 알 수 없는 status나 통지 누락(nil)은 실패로 처리한다.
  static func result(status: String?, token: String?) -> Result<VerificationResult, AuthError> {
    switch status.flatMap(Self.init(rawValue:)) {
    case .certified:
      // certified인데 토큰이 없으면 세션 재수립이 불가능하므로 성공으로 볼 수 없다.
      guard let token else {
        ESTLog.error("verification certified but token is missing")
        return .failure(.verificationFailed)
      }
      return .success(VerificationResult(token: token))

    case .cancelled:
      return .failure(.cancelled)

    case .error, .none:
      ESTLog.error("verification failed — status: \(status ?? "nil")")
      return .failure(.verificationFailed)
    }
  }
}
