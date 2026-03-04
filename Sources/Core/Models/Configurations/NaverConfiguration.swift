//
//  NaverConfiguration.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/27/26.
//

import Foundation

public struct NaverConfiguration {
  public let appName: String
  public let clientID: String
  public let clientSecret: String
  public let urlScheme: String

  public init(appName: String, clientID: String, clientSecret: String, urlScheme: String) {
    self.appName = appName
    self.clientID = clientID
    self.clientSecret = clientSecret
    self.urlScheme = urlScheme
  }
}
