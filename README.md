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

## 외부에서 주입해야 할 값

SDK 통합 시 앱에서 직접 주입해야 하는 값 목록입니다. 값이 유출되면 안 되는 항목은 `.xcconfig`, 키체인, 빌드 환경 변수 등으로 분리 관리하는 것을 권장합니다.

### 필수

| 항목 | 주입 위치 | 설명 |
|------|----------|------|
| `clientId` | `ESTLoginConfiguration.Builder(clientId:)` | ESTLoginKit에서 발급받은 클라이언트 ID |

### 플랫폼 (카카오·네이버 모두 필수)

| 플랫폼 | 항목 | 주입 위치 |
|-------|------|----------|
| 카카오 | `appKey` | `KakaoConfiguration(appKey:)` → `.useKakao(_:)` |
| 카카오 | `customScheme` (선택) | `KakaoConfiguration(appKey:customScheme:)` → `.useKakao(_:)` |
| 카카오 | URL Scheme `kakao{APP_KEY}` | `Info.plist` > `CFBundleURLTypes` |
| 네이버 | `appName` | `NaverConfiguration(appName:...)` → `.useNaver(_:)` |
| 네이버 | `clientID` | `NaverConfiguration(clientID:...)` |
| 네이버 | `clientSecret` | `NaverConfiguration(clientSecret:...)` |
| 네이버 | `urlScheme` | `NaverConfiguration(urlScheme:...)` + `Info.plist` > `CFBundleURLTypes` |

### 선택 (미지정 시 기본값 사용)

| 항목 | 주입 위치 | 기본값 / 설명 |
|------|----------|-------------|
| `environment` | `Builder.useEnvironment(_:)` | `.production`(기본) / `.development` / `.test`. 웹·API host가 환경별로 함께 결정됨 |
| `redirectURL` | `ESTLoginManager.shared.loginURL(redirectURL:)` | `{baseURL}/auth/app-callback` |
| `state` | `ESTLoginManager.shared.loginURL(state:)` | 없음. ZUM 전용 state URL 매칭 흐름에서만 사용 |
| `callbackURL` | `LoginWebView(callbackURL:)` / `LoginWebViewController(callbackURL:)` | `{baseURL}/auth/app-callback`(기본). 해당 URL로 리다이렉트되면 `code` 쿼리를 `ssoToken`으로 추출해 completion 호출. `nil` 명시 시 감지 비활성화 |
| `externalUserAgent` | `LoginWebView(externalUserAgent:)` | nil. 커스텀 User-Agent가 필요한 경우 지정 |
| `inspectable` | `LoginWebView(inspectable:)` | `false`. Safari Web Inspector 활성화 (iOS 16.4+) |

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

#### 실행 환경 지정 (선택)

개발/스테이징 대응이 필요하면 `useEnvironment(_:)`로 환경을 지정합니다. 미지정 시 기본값은 `.production` 입니다. 웹 host와 API host가 환경에 따라 쌍으로 자동 결정됩니다.

| 환경 | 웹 host | API host |
|------|---------|----------|
| `.production` (기본) | estoneid.com | api.estoneid.com |
| `.development` | dev.estoneid.com | dev-api.estoneid.com |
| `.test` | test.estoneid.com | test-api.estoneid.com |

```swift
let config = ESTLoginConfiguration.Builder(clientId: "YOUR_CLIENT_ID")
    .useEnvironment(.development) // 기본값: .production
    .useKakao(KakaoConfiguration(appKey: "YOUR_KAKAO_NATIVE_APP_KEY"))
    .build()
```

`ESTLoginManager.shared.loginURL()`과 `mypageURL`이 이 환경의 웹 base URL을 기준으로 생성됩니다.

#### 카카오 커스텀 스킴 (개발/운영 앱 분리 시 필수)

개발 앱과 운영 앱이 동일한 카카오 앱 키를 사용하는 경우, URL Scheme(`kakao{APP_KEY}`)이 동일하므로 카카오 인증 후 콜백이 운영 앱으로 열릴 수 있습니다. 이를 방지하려면 `customScheme`을 지정하여 개발 앱 전용 스킴으로 분리합니다.

```swift
// 개발 앱 — 커스텀 스킴으로 콜백이 개발 앱으로 돌아오도록 지정
let config = ESTLoginConfiguration.Builder(clientId: "YOUR_CLIENT_ID")
    .useEnvironment(.development)
    .useKakao(KakaoConfiguration(
        appKey: "YOUR_KAKAO_NATIVE_APP_KEY",
        customScheme: "kakao{APP_KEY}dev"  // 개발 전용 스킴
    ))
    .build()
```

`customScheme`을 지정하면 `KakaoSDK.initSDK(appKey:customScheme:)`에 전달됩니다. 카카오 개발자 콘솔에서도 해당 커스텀 스킴을 등록하고, `Info.plist`의 `CFBundleURLTypes`에도 동일한 스킴을 추가해야 합니다.

> **운영 앱**은 `customScheme`을 지정하지 않으면 기본 스킴(`kakao{APP_KEY}`)이 사용됩니다.

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
// 기본 (redirect_url = {baseURL}/auth/app-callback)
let loginURL = await ESTLoginManager.shared.loginURL()

// redirect_url 직접 지정
let loginURL = await ESTLoginManager.shared.loginURL(redirectURL: "https://example.com/callback")

// state 전달 (선택)
let loginURL = await ESTLoginManager.shared.loginURL(state: "https://m.zum.com")

// redirect_url + state 동시 지정
let loginURL = await ESTLoginManager.shared.loginURL(
    redirectURL: "https://example.com/callback",
    state: "https://m.zum.com"
)
```

> `state`는 **선택 파라미터**입니다. 생략하면 URL에 `state` 쿼리 자체가 포함되지 않습니다. `redirectURL`과 독립적으로 동작하므로 둘 중 하나만, 둘 다, 또는 모두 생략해도 됩니다.

생성되는 URL 형식:
```
https://estoneid.com/user/login
  ?type=callback
  &client_id={발급받은 클라이언트 ID}
  &redirect_url=https://estoneid.com/auth/app-callback
  &state={앱이 전달할 임의 값 (선택)}
```

### 콜백 흐름

1. **SSO 콜백**: `callbackURL`로 리다이렉트되면 쿼리의 `code` 값을 `ssoToken`으로 추출하여 `completion(ssoToken)`을 호출합니다. 기본값은 `ESTLoginManager.shared.appCallbackURL`(`{baseURL}/auth/app-callback`)이며, `nil`을 명시하면 이 감지는 비활성화됩니다.
2. **state URL 매칭 (ZUM 전용)**: 초기 URL의 `state` 쿼리 파라미터와 동일한 URL로 이동하면 `completion(nil)`을 호출합니다. 이 방식은 ZUM 서비스 전용이며, 일반적인 경우 SSO 콜백 방식을 사용하세요.

`LoginWebView` / `LoginWebViewController`는 다음 시그니처를 가집니다.

```swift
LoginWebView(
    url: URL = ESTLoginManager.shared.loginURL(),
    callbackURL: String? = ESTLoginManager.shared.appCallbackURL,  // "{baseURL}/auth/app-callback"
    externalUserAgent: String? = nil,
    inspectable: Bool = false,
    completion: ((String?) -> Void)? = nil
)
```

> **dismiss는 호출부에서 처리해야 합니다.**
> `LoginWebView` / `LoginWebViewController`는 화면 닫기를 직접 처리하지 않습니다.
> push, modal, custom transition 등 표시 방식에 따라 `completion` 클로저 안에서 직접 dismiss/pop을 구현하세요.

**SwiftUI**

```swift
.sheet(isPresented: $showWebView) {
    LoginWebView(
        url: loginURL,
        callbackURL: "https://estoneid.com/auth/app-callback"
    ) { ssoToken in
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

마이페이지는 **SSO 부트스트랩 요청으로 여는 것을 권장**합니다. 웹뷰 쿠키가 없거나 만료된
상태에서도 앱의 accessToken으로 웹 세션을 새로 수립하므로, 사용자가 로그인 화면을 다시 보지
않습니다. (자세한 동작은 아래 [SSO 토큰](#sso-토큰-웹뷰-세션-수립) 참고)

**SwiftUI**

```swift
.sheet(isPresented: $showMypage) {
    MyPageWebView(
        accessToken: accessToken,
        onError: { _ in showMypage = false }  // ssoToken 발급 실패 (만료 토큰 등)
    )
    .ignoresSafeArea()
}
```

**UIKit**

```swift
let request = try await ESTLoginManager.shared.authorizedMypageRequest(accessToken: accessToken)
let vc = ESTOneWebViewController(request: request)
present(vc, animated: true)
```

> 웹뷰 세션 쿠키(`WKWebsiteDataStore.default()`)가 살아있는 경우에는
> `MyPageWebView(url: ESTLoginManager.shared.mypageURL)`로 직접 진입할 수도 있습니다.

## SSO 토큰 (웹뷰 세션 수립)

마이페이지·본인인증 웹뷰가 기존 웹뷰 세션/쿠키에 의존하지 않도록, SDK가 앱의 accessToken으로
일회성 SSO 토큰을 발급받아(`GET {apiBaseURL}/auth/sso/sso-token`) 웹의 부트스트랩 URL로 전달합니다.

```http
GET {baseURL}/webview/sso-login?code={ssoToken}&redirect_url={URL인코딩된 내부 경로}
```

- `code` (필수): 직전에 발급받은 ssoToken. 유효시간 60초
- `redirect_url` (선택): 세션 수립 후 이동할 내부 경로(자체 쿼리 포함 전체를 1회 URL인코딩). 생략 시 홈(`/`)으로 이동. 외부 URL은 홈으로 대체됩니다

웹은 `code`를 검증해 자체 세션 쿠키를 수립한 뒤 `redirect_url`로 이동시키므로,
쿠키가 없는 기기/상태에서도 웹뷰를 열 수 있습니다. `code`가 만료 등으로 실패하면
웹이 기존 세션을 정리하고 로그인 화면으로 보내며, 로그인 후 `redirect_url`로 복귀하므로
앱의 별도 처리는 필요 없습니다.

- SSO 토큰은 **유효 60초, 1회용**, AES256 암호화 문자열(파싱 금지)입니다.
- 유효시간이 짧으므로 **웹뷰를 여는 시점마다 새로 발급**하세요. 미리 발급해 두면 만료돼 사용자가 불필요하게 로그인 화면을 보게 됩니다.
- Keychain 등에 **저장하거나 로그로 출력하지 마세요.**
- SDK는 stateless — **유효한 accessToken을 파라미터로 받는다고 가정**합니다. 만료 판단·갱신(refreshToken)은 앱 책임이며, 만료된 토큰을 넘기면 `AuthError.server(statusCode: 401)`이 던져집니다. 앱이 토큰을 갱신한 뒤 재호출하세요.

```swift
// 유효한 accessToken을 앱이 준비해서 넘긴다 (만료면 앱이 먼저 갱신)
let accessToken = await tokenStore.validAccessToken()

// 뷰에 accessToken만 넘기면 발급→부트스트랩→진입까지 SDK가 처리 (여는 시점마다 새로 발급)
MyPageWebView(accessToken: accessToken, onError: { _ in ... })
IdentityVerificationView(accessToken: accessToken) { result in ... }

// 요청을 직접 만들어야 하면 (UIKit 등)
let mypageRequest = try await ESTLoginManager.shared.authorizedMypageRequest(accessToken: accessToken)
let verificationRequest = try await ESTLoginManager.shared.authorizedVerificationRequest(accessToken: accessToken)

// 토큰만 직접 필요하면
let ssoToken = try await ESTLoginManager.shared.issueSSOToken(accessToken: accessToken)
```

> accessToken이 만료됐거나 유효하지 않으면 `AuthError.server(statusCode: 401)`이 던져집니다.
> 앱이 refreshToken으로 갱신한 뒤 재호출하세요. (SDK는 재시도하지 않습니다)

## 에러 처리

`ESTLoginManager.shared.login(with:)`는 성공 시 `AuthResult`를 반환하고, 실패 시 **각 제공자 SDK의 원본 에러를 그대로 전달**합니다. 사용자 취소·네트워크 오류·인증 실패 등은 모두 `KakaoSDK` / `NidThirdPartyLogin`에서 정의한 에러 타입으로 올라옵니다.

ESTLoginKit 자체가 정의한 타입은 다음 하나뿐이며, 현재 구현 흐름에선 실제로 던져지지 않습니다. (향후 미지원 플랫폼 호출 대비용)

```swift
public enum AuthError: Error {
  case unsupportedPlatform
  case unknown(Error?)
}
```

기본 사용 예:

```swift
do {
    let result = try await ESTLoginManager.shared.login(with: .kakao)
    // 성공 처리
} catch {
    // 카카오: KakaoSDKCommon.SdkError 등
    // 네이버: NidThirdPartyLogin에서 전달하는 Error
    print("로그인 실패: \(error)")
}
```

각 SDK의 에러 상세 분류가 필요하다면 카카오/네이버 공식 문서를 참고하세요.

> **웹뷰 로그인의 completion**
> `LoginWebView` / `LoginWebViewController`의 `completion` 콜백은 `(String?) -> Void` 이며 에러를 던지지 않습니다.
> - `ssoToken`이 **non-nil**: `callbackURL`에서 `code` 쿼리 추출에 성공.
> - `ssoToken`이 **nil**: 초기 URL의 `state` 파라미터와 매칭되는 URL로 이동한 경우(ZUM 전용 흐름). 일반적인 경우 `callbackURL`을 전달해 non-nil 케이스로 성공을 판정하세요.

## 레퍼런스
- [Kakao developers](https://developers.kakao.com/docs/latest/ko/ios/getting-started#project)
- [Naver Login SDK iOS](https://developers.naver.com/docs/login/ios/ios.md)
