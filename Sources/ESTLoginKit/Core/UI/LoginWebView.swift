//
//  LoginWebView.swift
//  ESTLoginKit
//
//  Created by ESTAID on 3/11/26.
//

import SwiftUI

public struct LoginWebView: UIViewControllerRepresentable {

  private let url: URL
  private let externalUserAgent: String?
  private let completion: (() -> Void)?

  public init(
    url: URL,
    externalUserAgent: String? = nil,
    completion: (() -> Void)? = nil
  ) {
    self.url = url
    self.externalUserAgent = externalUserAgent
    self.completion = completion
  }

  public func makeUIViewController(context: Context) -> LoginWebViewController {
    LoginWebViewController(url: url, externalUserAgent: externalUserAgent, completion: completion)
  }

  public func updateUIViewController(_ uiViewController: LoginWebViewController, context: Context) {}
}
