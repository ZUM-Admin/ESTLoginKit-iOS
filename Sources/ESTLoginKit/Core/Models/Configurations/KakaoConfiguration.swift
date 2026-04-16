//
//  KakaoConfiguration.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/27/26.
//

import Foundation

public struct KakaoConfiguration {
  public let appKey: String
  public let customScheme: String?

  public init(appKey: String, customScheme: String? = nil) {
    self.appKey = appKey
    self.customScheme = customScheme
  }
}
