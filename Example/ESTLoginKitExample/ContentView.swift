//
//  ContentView.swift
//  ESTLoginKitExample
//

import SwiftUI
import ESTLoginKit

struct ContentView: View {

  @StateObject private var viewModel = LoginViewModel()

  var body: some View {
    NavigationStack {
      if viewModel.isLoggedIn {
        LoggedInView(token: viewModel.token, onLogout: viewModel.logout)
      } else {
        LoginView(viewModel: viewModel)
      }
    }
  }
}

// MARK: - Login View

private struct LoginView: View {

  @ObservedObject var viewModel: LoginViewModel

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

        LoginButton(
          title: "Google로 계속하기",
          icon: "globe",
          foreground: .black,
          background: .white,
          bordered: true
        ) {
          viewModel.login(with: .google)
        }

        LoginButton(
          title: "Apple로 계속하기",
          icon: "apple.logo",
          foreground: .white,
          background: .black
        ) {
          viewModel.login(with: .apple)
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

  let token: String?
  let onLogout: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.green)

      Text("로그인 성공!")
        .font(.title2)
        .bold()

      if let token {
        GroupBox("토큰") {
          ScrollView {
            Text(token)
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxHeight: 120)
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
