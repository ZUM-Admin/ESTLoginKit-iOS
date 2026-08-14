//
//  WebEventPayload.swift
//  ESTLoginKit
//

import Foundation

/// 웹 → 네이티브 이벤트 페이로드 파서.
///
/// `properties`는 스키마가 없습니다 — 웹이 시트에 행을 추가하는 것만으로 키가 늘어납니다.
/// 그래서 `Decodable` DTO로 고정하지 않고 `JSONSerialization` 결과를 그대로 넘깁니다.
/// (DTO로 박으면 키가 추가될 때마다 SDK를 배포해야 합니다)
enum WebEventParser {

  /// `postMessage` 본문을 `ESTWebEvent`로 변환한다.
  ///
  /// 본문은 두 형태 모두 받는다:
  /// - `postMessage(JSON.stringify({...}))` → `String`
  /// - `postMessage({...})` → `[String: Any]` (WebKit이 JS 객체를 자동 변환)
  ///
  /// 웹이 어느 쪽으로 구현하든 동작하게 해서 계약 불일치로 인한 왕복을 없앤다.
  ///
  /// - Returns: 파싱 실패 / `event_key` 부재 시 `nil`. 이벤트 하나 때문에 로그인 흐름이
  ///   막히면 안 되므로 throw하지 않는다.
  static func parse(_ body: Any?) -> ESTWebEvent? {
    guard let (object, raw) = normalize(body) else { return nil }

    // `event_key`(웹 표기)와 `eventKey`(카멜) 둘 다 받는다 — 웹 구현이 어느 쪽으로 굳어져도
    // SDK를 다시 배포하지 않기 위해서다.
    guard let eventKey = (object["event_key"] ?? object["eventKey"]) as? String,
          !eventKey.isEmpty
    else { return nil }

    let properties = (object["properties"] as? [String: Any]).map { sanitize($0) } ?? [:]
    return ESTWebEvent(eventKey: eventKey, properties: properties, raw: raw)
  }

  /// 본문을 `(딕셔너리, 원본 문자열)`로 정규화한다.
  private static func normalize(_ body: Any?) -> ([String: Any], String)? {
    if let json = body as? String {
      guard let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return nil }
      return (object, json)
    }

    if let object = body as? [String: Any] {
      // 원본 문자열이 없는 경로 — 호스트가 raw를 볼 수 있게 다시 직렬화한다.
      // 직렬화 불가한 값이 섞이면 raw만 비운다(이벤트 자체는 살린다).
      let raw = (try? JSONSerialization.data(withJSONObject: object))
        .flatMap { String(data: $0, encoding: .utf8) } ?? ""
      return (object, raw)
    }

    return nil
  }

  /// JSON `null`(`NSNull`)을 중첩 구조까지 제거한다.
  ///
  /// 그냥 두면 호스트가 `properties["x"]`를 옵셔널 체크로 통과시킨 뒤 `NSNull`을 분석 SDK에
  /// 그대로 넘기게 된다. 값이 없다는 뜻이면 키도 없는 편이 다루기 쉽다.
  private static func sanitize(_ dictionary: [String: Any]) -> [String: Any] {
    dictionary.reduce(into: [String: Any]()) { result, entry in
      guard let value = sanitize(value: entry.value) else { return }
      result[entry.key] = value
    }
  }

  private static func sanitize(value: Any) -> Any? {
    switch value {
    case is NSNull:
      return nil
    case let nested as [String: Any]:
      return sanitize(nested)
    case let array as [Any]:
      return array.compactMap { sanitize(value: $0) }
    default:
      return value
    }
  }
}
