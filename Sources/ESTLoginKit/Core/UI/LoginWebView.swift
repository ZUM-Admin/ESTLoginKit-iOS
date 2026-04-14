//
//  LoginWebView.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/11/26.
//

import SwiftUI

public struct LoginWebView: UIViewControllerRepresentable {

  private let url: URL
  private let callbackURL: String?
  private let externalUserAgent: String?
  private let inspectable: Bool
  private let completion: ((String?) -> Void)?

  public init(
    url: URL,
    callbackURL: String? = nil,
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    completion: ((String?) -> Void)? = nil
  ) {
    self.url = url
    self.callbackURL = callbackURL
    self.externalUserAgent = externalUserAgent
    self.inspectable = inspectable
    self.completion = completion
  }

  public func makeUIViewController(context: Context) -> LoginWebViewController {
    LoginWebViewController(
      url: url,
      callbackURL: callbackURL,
      externalUserAgent: externalUserAgent,
      inspectable: inspectable,
      completion: completion
    )
  }

  public func updateUIViewController(_ uiViewController: LoginWebViewController, context: Context) {}
}
