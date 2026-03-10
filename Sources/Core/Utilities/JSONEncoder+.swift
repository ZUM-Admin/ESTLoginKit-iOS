//
//  JSONEncoder+.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/10/26.
//

import Foundation

extension JSONEncoder {
  static let instance: JSONEncoder = {
    return $0
  }(JSONEncoder())
}

extension Encodable {
  var jsonString: String? {
    guard let data = try? JSONEncoder.instance.encode(self) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}
