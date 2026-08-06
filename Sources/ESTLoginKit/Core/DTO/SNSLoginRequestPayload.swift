//
//  SNSLoginRequestPayload.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/26/26.
//

import Foundation

struct SNSLoginRequestPayload: Decodable {
  let type: String
  /// 웹이 보낸 원본 provider 문자열.
  ///
  /// enum으로 받으면 네이티브 미지원 값(google/apple 등)에서 디코딩 자체가 실패해
  /// 어떤 provider가 거부됐는지 웹에 통지할 수 없다. String으로 받아 디코딩은 통과시키고,
  /// `LoginPlatform` 매핑 단계에서 `unsupported_provider` 에러를 웹에 돌려준다. (Android 동작과 동일)
  let provider: String
}

extension SNSLoginRequestPayload {
  /// 네이티브 SDK로 처리 가능한 플랫폼. 미지원이면 nil.
  /// 웹이 "Kakao"처럼 대소문자를 섞어 보내도 받아준다. (Android `LoginPlatform.from` 과 동일)
  var platform: LoginPlatform? {
    LoginPlatform(rawValue: provider.lowercased())
  }
}
