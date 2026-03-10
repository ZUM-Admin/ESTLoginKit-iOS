//
//  LoginViewModel.swift
//  ESTLoginKitExample
//

import Combine
import Foundation

import ESTLoginKit

@MainActor
final class LoginViewModel: ObservableObject {

  @Published var isLoggedIn = false
  @Published var token: String?
  @Published var errorMessage: String?
  @Published var isLoading = false

  func login(with platform: LoginPlatform) {
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let result = try await ESTLoginManager.shared.login(with: platform)
        self.token = result
        self.isLoggedIn = true
      } catch AuthError.unsupportedPlatform {
        self.errorMessage = "지원하지 않는 플랫폼입니다."
      } catch {
        self.errorMessage = error.localizedDescription
      }
      self.isLoading = false
    }
  }

  func logout() {
    token = nil
    isLoggedIn = false
  }
}
