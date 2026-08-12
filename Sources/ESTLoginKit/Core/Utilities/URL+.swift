//
//  URL+.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/11/26.
//

import Foundation

extension URL {
  func queryValue(for name: String) -> String? {
    URLComponents(url: self, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == name })?
      .value
  }

  /// 값이 비어 있는 쿼리 파라미터("?code=")를 nil로 취급한다.
  /// URLQueryItem은 이 경우 nil이 아닌 빈 문자열을 돌려주므로, 빈 값을
  /// 유효한 값으로 오인하지 않으려면 별도 가드가 필요하다.
  func nonEmptyQueryValue(for name: String) -> String? {
    guard let value = queryValue(for: name), !value.isEmpty else { return nil }
    return value
  }

  /// 값을 그대로 남겨도 되는 쿼리 파라미터. 나머지는 전부 마스킹한다(deny by default).
  ///
  /// 외부 IdP 로그인은 우리가 모르는 이름으로 민감정보를 실어 나른다.
  /// (Apple federation: `accountName`·`login_hint`=이메일, `token`·`relayState`=인증 토큰)
  /// 허용 목록을 두지 않으면 새 파라미터가 생길 때마다 로그로 새어 나간다.
  private static let logSafeQueryNames: Set<String> = [
    "client_id", "type", "id", "status", "state", "redirect_url", "to",
  ]

  /// 로그 출력용 문자열. 호스트·경로와 파라미터 "이름"은 남기고 값은 마스킹한다.
  ///
  /// 로그는 `privacy: .public` 으로 시스템 로그에 남고 그대로 공유되기도 하므로,
  /// 플로우 진단에 필요한 최소치만 남긴다. 빈 값(`?code=`)은 빈 채로 둔다 —
  /// 빈 파라미터가 유효값을 덮어쓰는 종류의 버그를 로그에서 구분할 수 있어야 한다.
  var redactedForLog: String {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
          let items = components.queryItems, !items.isEmpty
    else { return absoluteString }

    components.queryItems = items.map { item in
      guard !Self.logSafeQueryNames.contains(item.name),
            !(item.value ?? "").isEmpty
      else { return item }
      return URLQueryItem(name: item.name, value: "***")
    }
    return components.url?.absoluteString ?? absoluteString
  }
}
