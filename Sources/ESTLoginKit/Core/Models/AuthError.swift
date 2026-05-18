//
//  AuthError.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

public enum AuthError: Error {
  case unsupportedPlatform
  case cancelled
  case unknown(Error?)
}

