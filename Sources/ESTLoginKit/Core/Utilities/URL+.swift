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
}
