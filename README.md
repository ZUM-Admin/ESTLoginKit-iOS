# ESTLoginKit

iOS 소셜 로그인을 간편하게 통합할 수 있는 Swift Package입니다.

## 요구사항

- iOS 16.0+
- Swift 5.7+
- Xcode 15+

## 지원 플랫폼

| 플랫폼 | 지원 여부 |
|--------|----------|
| 카카오 | ✅ |
| 네이버 | ✅ |

## 설치

### Swift Package Manager

`Package.swift`에 의존성을 추가합니다.

```swift
dependencies: [
    .package(url: "https://github.com/ZUM-Internet/ESTLoginKit-iOS", from: "1.0.0")
]
```

또는 Xcode에서 **File > Add Package Dependencies** 를 통해 URL을 입력해 추가할 수 있습니다.

## 설정

### 1. 초기화

앱 시작 시점(`AppDelegate` 또는 `@main` 진입점)에서 SDK를 초기화합니다.

```swift
import ESTLoginKit

let config = ESTLoginConfiguration.Builder(clientId: "YOUR_CLIENT_ID")
    .useKakao(KakaoConfiguration(appKey: "YOUR_KAKAO_NATIVE_APP_KEY"))
    .useNaver(NaverConfiguration(appName: "앱이름", clientID: "CLIENT_ID", clientSecret: "SECRET", urlScheme: "YOUR_SCHEME"))
    .build()

await ESTLoginManager.shared.initialize(with: config)
```

### 2. URL 핸들링

로그인 콜백 처리를 위해 URL 핸들러를 등록합니다.

**SwiftUI**

```swift
import ESTLoginKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task {
                        await ESTLoginManager.shared.handle(url)
                    }
                }
        }
    }
}
```

**UIKit**

```swift
// AppDelegate
func application(_ app: UIApplication, open url: URL, options: [...]) -> Bool {
    return await ESTLoginManager.shared.handle(url)
}
```

```swift
// SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
        _ = ESTLoginManager.shared.handle(url)
    }
}
```

### 3. Info.plist 설정

로그인을 사용하려면 `Info.plist`에 아래 항목을 추가해야 합니다.

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string> <!-- 카카오 -->
    <string>naversearchapp</string> <!-- 네이버 -->
    <string>naversearchthirdlogin</string> <!-- 네이버 -->
</array>

```

### 4. 커스텀 URL 스킴

**카카오**
서비스 앱 실행을 위해 커스텀 URL 스킴 설정을 합니다.
[Info] > [URL Types] > [URL Schemes] 항목에 네이티브 앱 키(Native App Key)를 kakao${NATIVE_APP_KEY} 형식으로 등록합니다.
예를 들어 네이티브 앱 키가 "123456789"라면 [URL Schemes]에 "kakao123456789"를 입력합니다.

**네이버**

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>{URL Scheme Identifier}</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>{콜백 URL Scheme}</string>
    </array>
  </dict>
</array>
```

## 사용법

```swift
import ESTLoginKit

do {
    let result = try await ESTLoginManager.shared.login(with: .kakao)
    print("토큰: \(result.authorizeToken)")
    print("리프레시 토큰: \(result.refreshToken)")
    print("이메일: \(result.email)")
} catch AuthError.unsupportedPlatform {
    print("지원하지 않는 플랫폼입니다.")
} catch {
    print("로그인 실패: \(error)")
}
```

## 로그아웃

```swift
try await ESTLoginManager.shared.logout()
```

카카오와 네이버 로그아웃을 함께 처리합니다.

> **네이버는 키체인에 토큰 정보를 저장합니다.**
> 네이버 로그인 SDK는 인증 토큰을 기기의 키체인에 보관하므로, 로그아웃 시점에 반드시 `logout()`을 호출하여 저장된 토큰을 제거해야 합니다.
> 호출하지 않으면 앱을 재설치하더라도 이전 토큰이 키체인에 남아 있을 수 있습니다.

## 웹뷰 로그인

`LoginWebView` (SwiftUI) 또는 `LoginWebViewController` (UIKit)를 사용해 웹 기반 로그인을 구현할 수 있습니다.

웹뷰 로그인은 SSO 콜백 방식으로 동작하며, `completion` 클로저는 `(String?) -> Void` 타입입니다.

### 로그인 URL 구성

SDK에서 로그인 URL을 생성할 수 있습니다. `initialize()` 시 전달한 `clientId`가 자동으로 포함됩니다.

```swift
// 기본 (redirect_url = https://estoneid.com/auth/app-callback)
let loginURL = await ESTLoginManager.shared.loginURL()

// state 전달
let loginURL = await ESTLoginManager.shared.loginURL(state: "https://m.zum.com")

// redirect_url 직접 지정
let loginURL = await ESTLoginManager.shared.loginURL(redirectURL: "https://example.com/callback", state: "custom")
```

생성되는 URL 형식:
```
https://estoneid.com/user/login
  ?type=callback
  &client_id={발급받은 클라이언트 ID}
  &redirect_url=https://estoneid.com/auth/app-callback
  &state={앱이 전달할 임의 값 (선택)}
```

### 콜백 흐름

1. **SSO 콜백**: 로그인 완료 후 `https://estoneid.com/auth/app-callback?code={ssoToken}&state={state}` 로 리다이렉트되면, `ssoToken`을 추출하여 `completion(ssoToken)`을 호출합니다.
2. **state URL 매칭 (ZUM 전용)**: 초기 URL의 `state` 쿼리 파라미터와 동일한 URL로 이동하면 `completion(nil)`을 호출합니다. 이 방식은 ZUM 서비스 전용이며, 일반적인 경우 SSO 콜백 방식을 사용하세요.

> **dismiss는 호출부에서 처리해야 합니다.**
> `LoginWebView` / `LoginWebViewController`는 화면 닫기를 직접 처리하지 않습니다.
> push, modal, custom transition 등 표시 방식에 따라 `completion` 클로저 안에서 직접 dismiss/pop을 구현하세요.

**SwiftUI**

```swift
.sheet(isPresented: $showWebView) {
    LoginWebView(url: loginURL) { ssoToken in
        if let ssoToken {
            print("SSO 토큰: \(ssoToken)")
        }
        showWebView = false
    }
    .ignoresSafeArea()
}
```

**UIKit (modal)**

```swift
let vc = LoginWebViewController(url: loginURL) { [weak self] ssoToken in
    if let ssoToken {
        print("SSO 토큰: \(ssoToken)")
    }
    self?.dismiss(animated: true)
}
present(vc, animated: true)
```

**UIKit (push)**

```swift
let vc = LoginWebViewController(url: loginURL) { [weak self] ssoToken in
    self?.navigationController?.popViewController(animated: true)
}
navigationController?.pushViewController(vc, animated: true)
```

### 웹뷰 디버깅 (Safari Web Inspector)

`inspectable: true`를 전달하면 iOS 16.4 이상에서 Safari Web Inspector로 웹뷰를 디버깅할 수 있습니다. 기본값은 `false`입니다.

**SwiftUI**

```swift
LoginWebView(url: loginURL, inspectable: true) { ssoToken in
    showWebView = false
}
```

**UIKit**

```swift
let vc = LoginWebViewController(url: loginURL, inspectable: true) { [weak self] ssoToken in
    self?.dismiss(animated: true)
}
```

## 마이페이지

로그인과 동일한 웹뷰를 사용하여 마이페이지를 열 수 있습니다. `WKWebsiteDataStore.default()`를 통해 쿠키가 공유되므로, 로그인 세션이 유지된 상태에서 마이페이지에 접근할 수 있습니다.

**SwiftUI**

```swift
.sheet(isPresented: $showMypage) {
    LoginWebView(url: await ESTLoginManager.shared.mypageURL)
        .ignoresSafeArea()
}
```

**UIKit**

```swift
let mypageURL = await ESTLoginManager.shared.mypageURL
let vc = LoginWebViewController(url: mypageURL)
present(vc, animated: true)
```

## 에러 처리

| 에러 | 설명 |
|------|------|
| `AuthError.unsupportedPlatform` | 아직 구현되지 않은 플랫폼으로 로그인 시도 |
| `AuthError.unknown(Error?)` | 알 수 없는 오류 |

## 레퍼런스
- [Kakao developers](https://developers.kakao.com/docs/latest/ko/ios/getting-started#project)
- [Naver Login SDK iOS](https://developers.naver.com/docs/login/ios/ios.md)
