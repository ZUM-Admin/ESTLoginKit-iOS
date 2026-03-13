//
//  File.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/26/26.
//

import Foundation

public extension JSONDecoder {
  static let instance: JSONDecoder = {
    return $0
  }(JSONDecoder())
}
