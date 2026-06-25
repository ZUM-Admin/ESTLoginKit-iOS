//
//  ContentView.swift
//  ESTLoginKitExample
//

import SwiftUI
import ESTLoginKit

struct ContentView: View {

  @StateObject private var viewModel = LoginViewModel()
  @State private var webLoginURL: URL?

  // 실제 서비스 연동 시 각자의 redirect/callback URL로 교체하세요.
  private let callbackURL = "YOUR_CALLBACK_URL" // 예: https://estoneid.com/auth/app-callback

  var body: some View {
    NavigationStack {
      if viewModel.isLoggedIn {
        LoggedInView(authResult: viewModel.authResult, onLogout: viewModel.logout)
      } else {
        LoginView(viewModel: viewModel, onWebLogin: startWebLogin)
      }
    }
    .sheet(item: Binding(
      get: { webLoginURL.map(IdentifiableURL.init) },
      set: { webLoginURL = $0?.url }
    )) { identifiable in
      LoginWebView(
        url: identifiable.url,
        callbackURL: callbackURL,
        completion: { ssoToken in
          print("로그인 성공 — ssoToken: \(ssoToken ?? "없음")")
          webLoginURL = nil
        }
      )
      .ignoresSafeArea()
    }
  }

  private func startWebLogin() {
    // SDK가 제공하는 loginURL 헬퍼를 사용하면 configuration의 clientId / baseURL이 자동 반영됩니다.
    // (nonisolated 동기 메서드라 await 불필요)
    webLoginURL = ESTLoginManager.shared.loginURL(
      redirectURL: callbackURL,
      state: "YOUR_STATE"
    )
  }
}

private struct IdentifiableURL: Identifiable {
  let url: URL
  var id: String { url.absoluteString }
}

// MARK: - Login View

private struct LoginView: View {

  @ObservedObject var viewModel: LoginViewModel
  let onWebLogin: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      VStack(spacing: 8) {
        Text("ESTLoginKit")
          .font(.largeTitle)
          .bold()
        Text("소셜 로그인 예제")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if viewModel.isLoading {
        ProgressView("로그인 중...")
      }

      if let error = viewModel.errorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      VStack(spacing: 12) {
        LoginButton(
          title: "카카오로 계속하기",
          icon: "message.fill",
          foreground: .black,
          background: Color(red: 1.0, green: 0.9, blue: 0.0)
        ) {
          viewModel.login(with: .kakao)
        }

        LoginButton(
          title: "네이버로 계속하기",
          icon: "n.circle.fill",
          foreground: .white,
          background: Color(red: 0.07, green: 0.62, blue: 0.27)
        ) {
          viewModel.login(with: .naver)
        }

        Divider()
          .padding(.vertical, 4)

        LoginButton(
          title: "웹뷰로 로그인",
          icon: "globe",
          foreground: .white,
          background: Color(red: 0.2, green: 0.4, blue: 0.9)
        ) {
          onWebLogin()
        }
      }
      .padding(.horizontal, 24)
      .disabled(viewModel.isLoading)

      Spacer()
    }
    .navigationTitle("")
  }
}

// MARK: - Logged In View

private struct LoggedInView: View {

  let authResult: AuthResult?
  let onLogout: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.green)

      Text("로그인 성공!")
        .font(.title2)
        .bold()

      if let result = authResult {
        VStack(spacing: 12) {
          TokenRow(label: "토큰", value: result.authorizeToken)
          if !result.refreshToken.isEmpty {
            TokenRow(label: "리프레시 토큰", value: result.refreshToken)
          }
          if !result.ci.isEmpty {
            TokenRow(label: "CI", value: result.ci)
          }
          if !result.email.isEmpty {
            TokenRow(label: "이메일", value: result.email)
          }
        }
        .padding(.horizontal)
      }

      Button("로그아웃", action: onLogout)
        .buttonStyle(.bordered)
        .tint(.red)
    }
    .navigationTitle("홈")
  }
}

private struct TokenRow: View {
  let label: String
  let value: String

  var body: some View {
    GroupBox(label) {
      ScrollView {
        Text(value)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 80)
    }
  }
}

// MARK: - Reusable Login Button

private struct LoginButton: View {

  let title: String
  let icon: String
  let foreground: Color
  let background: Color
  var bordered: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
        Text(title)
          .fontWeight(.semibold)
      }
      .foregroundStyle(foreground)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay {
        if bordered {
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        }
      }
    }
  }
}


#Preview {
  ContentView()
}
