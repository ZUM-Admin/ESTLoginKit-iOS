//
//  ContentView.swift
//  ESTLoginKit-iOS-Example
//
//  Created by ESTAID on 7/14/26.
//

import SwiftUI
import WebKit

import ESTLoginKit

struct ContentView: View {

  @State private var authResult: AuthResult?
  @State private var ssoToken: String?
  @State private var estoneToken: EstoneToken?
  @State private var statusMessage: String = "대기 중"

  // sheet(isPresented:) + 별도 상태 조합은 갱신 전(stale) 상태로 콘텐츠가 평가돼
  // 빈 화면이 뜰 수 있다. item 기반 sheet는 값이 클로저에 직접 전달되므로 안전하다.
  @State private var webSheet: WebSheet?

  private struct WebSheet: Identifiable {
    enum Kind: String { case mypage, verification, login, popupTest }

    let kind: Kind
    /// 웹뷰 부트스트랩용 accessToken — 뷰에 넘기면 SDK가 ssoToken 발급→세션 수립까지 처리.
    /// login은 nil 가능(accessToken 없으면 신규 로그인 `/user/login`).
    let accessToken: String?

    var id: String { kind.rawValue }
  }

  var body: some View {
    NavigationStack {
      List {
        Section("네이티브 로그인") {
          Button("카카오 로그인") { login(.kakao) }
          Button("네이버 로그인") { login(.naver) }
          Button("로그아웃", role: .destructive) { logout() }
        }

        Section("웹뷰") {
          Button("웹 로그인") { openLoginSheet() }
          Button("마이페이지") { openWebSheet(.mypage) }
          Button("본인인증") { openWebSheet(.verification) }
        }

        Section("디버그") {
          Button("팝업 처리 테스트") { webSheet = WebSheet(kind: .popupTest, accessToken: nil) }
        }

        Section("상태") {
          Text(statusMessage)
            .font(.footnote)
            .textSelection(.enabled)
        }

        if let result = authResult {
          Section("AuthResult (네이티브)") {
            row("authorizeToken", result.authorizeToken)
            row("refreshToken", result.refreshToken)
            row("ci", result.ci)
            row("email", result.email)
          }
        }

        if let ssoToken {
          Section("SSO Token (OAuth code)") {
            Text(ssoToken)
              .font(.footnote)
              .textSelection(.enabled)
          }
        }

        if let token = estoneToken {
          Section("EST 토큰") {
            row("accessToken", token.accessToken)
            row("refreshToken", token.refreshToken)
            row("만료 시각", token.expiryDate.formatted(date: .abbreviated, time: .standard))
            Button("토큰 갱신 (refresh-sso)") { renewToken() }
            Button("저장된 토큰 삭제", role: .destructive) {
              TokenStore.clear()
              estoneToken = nil
              statusMessage = "저장된 토큰 삭제됨"
            }
          }
        }
      }
      .navigationTitle("ESTLoginKit 테스트")
    }
    .onAppear {
      // 앱 재실행 시 저장된 토큰 복원
      if estoneToken == nil, let stored = TokenStore.load() {
        estoneToken = stored
        statusMessage = "저장된 토큰 복원됨"
      }
    }
    .sheet(item: $webSheet) { sheet in
      switch sheet.kind {
      case .login:
        loginWebView(accessToken: sheet.accessToken)
          .ignoresSafeArea()

      case .mypage:
        if let accessToken = sheet.accessToken {
          MyPageWebView(
            accessToken: accessToken,
            inspectable: true,
            onError: { error in
              statusMessage = "마이페이지 SSO 발급 실패: \(error)"
              webSheet = nil
            }
          )
          .ignoresSafeArea()
        }

      case .verification:
        if let accessToken = sheet.accessToken {
          VerificationView(accessToken: accessToken, inspectable: true) { result in
            switch result {
            case .success(let verification):
              statusMessage = "본인인증 성공: \(verification)"
            case .failure(let error):
              statusMessage = "본인인증 실패: \(error)"
            }
            webSheet = nil
          }
          .ignoresSafeArea()
        }

      case .popupTest:
        popupTestWebView()
          .ignoresSafeArea()
      }
    }
  }

  // MARK: - 팝업 처리 테스트

  /// `window.open` 처리 검증용. 회사 계정 없이 "팝업이 뜨는가"만 단독으로 확인한다.
  ///
  /// 로컬 파일(file://)은 SDK가 `load(URLRequest)`로 열어서 못 읽고, 로컬 http 서버는 ATS에
  /// 걸린다. `loadHTMLString(baseURL:)`이면 SDK 무수정으로 https origin까지 확보된다.
  private func popupTestWebView() -> some View {
    LoginWebView(
      url: URL(string: "https://example.com")!,  // 아래에서 테스트 HTML로 즉시 교체
      callbackURL: nil,                          // 콜백/state 매칭이 중간에 끼어들지 않게
      inspectable: true,
      onWebViewCreated: { webView in
        // WebViewController.setup()은 onWebViewCreated 직후 load(request)를 호출한다.
        // 한 틱 미뤄야 테스트 HTML이 살아남는다.
        DispatchQueue.main.async {
          webView.loadHTMLString(Self.popupTestHTML, baseURL: URL(string: "https://example.com"))
        }
      }
    )
  }

  private static let popupTestHTML = """
  <!doctype html>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font: 17px -apple-system; padding: 24px; }
    button, a { display: block; margin: 14px 0; padding: 14px; font-size: 16px; text-align: left; }
    #log div { font: 13px ui-monospace; color: #046; padding: 2px 0; }
  </style>
  <h3>window.open 처리 테스트</h3>
  <button onclick="caseA()">A. 빈 창 먼저 열고 이동 (federation 패턴)</button>
  <button onclick="caseB()">B. window.open(url, '_blank')</button>
  <a href="https://example.com" target="_blank">C. target="_blank" 링크</a>
  <div id="log"></div>
  <script>
    function say(s) {
      var d = document.createElement('div');
      d.textContent = s;
      document.getElementById('log').appendChild(d);
      console.log('[popup-test] ' + s);
    }
    function caseA() {
      var w = window.open('', '_blank');
      say('A: window.open() 반환값 = ' + w);
      if (!w) { say('A: 팝업 객체 없음 → 플로우 여기서 종료'); return; }
      w.location = 'https://example.com';
      say('A: location 설정 완료');
    }
    function caseB() {
      var w = window.open('https://example.com', '_blank');
      say('B: window.open() 반환값 = ' + w);
    }
  </script>
  """

  // MARK: - Actions

  /// 웹 로그인 진입. 유효한 accessToken이 있으면 마이페이지/본인인증처럼 SSO 부트스트랩(`/auth/sso-login`)으로,
  /// 없으면 신규 로그인(`/user/login`)으로 연다.
  private func openLoginSheet() {
    Task {
      let token = await validAccessToken()   // nil 가능
      webSheet = WebSheet(kind: .login, accessToken: token)
    }
  }

  /// 로그인 웹뷰 콘텐츠. 웹뷰 = 무조건 부트스트랩(`/auth/sso-login`).
  /// accessToken 있으면 code 실어 세션 수립, 없으면 code 없이 열고 웹이 로그인 페이지로 라우팅.
  private func loginWebView(accessToken: String?) -> some View {
    // 콜백 URL: Config의 EST_APP_CALLBACK이 있으면 그 값, 없으면 SDK 기본값(appCallbackURL).
    let callback = ExampleConfig.appCallback
    return LoginWebView(
      accessToken: accessToken,
      redirectURL: callback,
      callbackURL: callback ?? ESTLoginManager.shared.appCallbackURL,
      inspectable: true,
      onError: { error in
        statusMessage = "로그인 부트스트랩 실패: \(error)"
        webSheet = nil
      },
      completion: { token in
        webSheet = nil
        guard let token else {
          statusMessage = "웹 로그인 종료 (토큰 없음)"
          return
        }
        ssoToken = token
        issueEstoneToken(ssoToken: token)
      }
    )
  }

  /// 유효한 accessToken을 준비해 웹뷰를 연다. (ssoToken 발급은 뷰가 열릴 때 SDK가 수행)
  private func openWebSheet(_ kind: WebSheet.Kind) {
    Task {
      guard let accessToken = await validAccessToken() else {
        statusMessage = "유효한 accessToken 없음 — 로그인 필요"
        return
      }
      webSheet = WebSheet(kind: kind, accessToken: accessToken)
    }
  }

  /// 앱이 세션 SSoT — SDK는 유효한 accessToken을 받는다고 가정하므로,
  /// 만료 판단·갱신은 호출 전에 앱이 처리한다.
  private func validAccessToken() async -> String? {
    guard let stored = TokenStore.load() else { return nil }
    guard stored.expiryDate <= Date() else { return stored.accessToken }
    guard let renewed = try? await EstoneAuth.renewToken(stored) else { return nil }
    TokenStore.save(renewed)
    return renewed.accessToken
  }

  private func login(_ platform: LoginPlatform) {
    statusMessage = "\(platform) 로그인 중…"
    Task {
      do {
        let result = try await ESTLoginManager.shared.login(with: platform)
        authResult = result
        statusMessage = "\(platform) 로그인 성공"
      } catch {
        statusMessage = "\(platform) 로그인 실패: \(error)"
      }
    }
  }

  /// ssoToken(OAuth code) → access/refresh 발급 → UserDefaults 저장
  private func issueEstoneToken(ssoToken: String) {
    statusMessage = "EST 토큰 발급 중…"
    Task {
      do {
        let token = try await EstoneAuth.issueToken(ssoToken: ssoToken)
        estoneToken = token
        TokenStore.save(token)
        statusMessage = "EST 토큰 발급 완료 (저장됨)"
      } catch {
        statusMessage = "EST 토큰 발급 실패: \(error)"
      }
    }
  }

  private func renewToken() {
    guard let current = estoneToken else { return }
    statusMessage = "토큰 갱신 중…"
    Task {
      do {
        let renewed = try await EstoneAuth.renewToken(current)
        estoneToken = renewed
        TokenStore.save(renewed)
        statusMessage = "토큰 갱신 완료"
      } catch {
        statusMessage = "토큰 갱신 실패: \(error)"
      }
    }
  }

  private func logout() {
    Task {
      await ESTLoginManager.shared.logout()
      authResult = nil
      ssoToken = nil
      estoneToken = nil
      TokenStore.clear()
      statusMessage = "로그아웃 완료"
    }
  }

  private func row(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value.isEmpty ? "(빈 값)" : value)
        .font(.footnote)
        .lineLimit(3)
        .textSelection(.enabled)
    }
  }
}

#Preview {
  ContentView()
}
