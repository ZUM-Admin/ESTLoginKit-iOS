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
}
