//
//  ESTWebEvent.swift
//  ESTLoginKit
//

import Foundation

/// 웹이 `trackEvent` 브릿지로 올려보낸 이벤트.
///
/// SDK는 이 이벤트를 **해석하지 않고 그대로 호스트에 전달만 합니다.** 어떤 분석 도구로 보낼지,
/// 어떤 이벤트를 무시할지는 전부 호스트(SDK 소비처) 책임입니다.
///
/// 이렇게 두는 이유: 이벤트 목록은 웹 쪽에서 계속 늘어납니다. 이벤트마다 브릿지를 파면 행 하나
/// 추가할 때마다 SDK 양 플랫폼 수정 → 배포 → 호스트 앱 업데이트가 필요해집니다. `eventKey`로
/// 구분하는 단일 채널이면 SDK는 그대로 두고 웹만 움직이면 됩니다.
public struct ESTWebEvent {

  /// 웹이 정의한 이벤트 식별자. 예: `click__sns_login(app)`
  public let eventKey: String

  /// 이벤트 부가 정보. 웹이 보낸 JSON을 그대로 변환한 것이라 스키마가 없습니다.
  ///
  /// 값은 `String` / `Bool` / `Int` / `Double` / `Array` / `Dictionary` 중 하나이며,
  /// 중첩 구조가 올 수 있습니다. flat한 값만 받는 분석 SDK에 넘길 때는 호스트가 평탄화하세요.
  /// JSON `null`은 키 자체를 제외합니다 — `NSNull`이 분석 SDK로 새어나가지 않게 하기 위함입니다.
  public let properties: [String: Any]

  /// 웹이 보낸 원본 문자열. 파싱 결과가 미덥지 않을 때 호스트가 직접 해석하는 용도.
  public let raw: String

  init(eventKey: String, properties: [String: Any], raw: String) {
    self.eventKey = eventKey
    self.properties = properties
    self.raw = raw
  }
}
