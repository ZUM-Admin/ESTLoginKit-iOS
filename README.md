# ESTLoginKit

iOS 소셜 로그인 · 마이페이지 · **본인인증**을 간편하게 통합할 수 있는 Swift Package입니다.

> ## ⚠️ 토큰 관리는 이 SDK에서 하지 않습니다
>
> **ESTLoginKit은 stateless입니다.** 다음은 전부 **앱(호스트)의 책임**입니다:
> - `ssoToken` → `accessToken` / `refreshToken` **교환**
> - 토큰 **저장(Keychain)** · **갱신(refresh)** · **만료 처리**
> - 로그아웃 시 **앱이 저장한 토큰 삭제**
>
> SDK는 토큰을 **보관하지 않으며**, 토큰이 필요한 API(본인인증 여부 조회, SSO 부트스트랩)에는 **호출 시 호스트가 accessToken을 주입**합니다.

## 한눈에 보기 — ESTLoginKit이 제공하는 것

| ✅ SDK가 제공 | 🙅 앱(호스트) 책임 |
|---|---|
| 카카오·네이버 **네이티브 로그인** | ssoToken → accessToken/refreshToken **교환** |
| **웹뷰 로그인 화면** (구글·애플 포함) + ssoToken 회수 | 토큰 **저장(Keychain)·갱신·만료** 처리 |
| **로그인 URL 빌더** (`loginURL`, `silent`) | 본인인증을 **언제 띄울지(정책)** |
| **마이페이지 화면** (SSO 부트스트랩) + 계정 이벤트 통지 콜백 | 화면 **present / dismiss** |
| **로그아웃** (네이티브 SDK 토큰 정리) | 로그인 결과 후속 처리(서버 통신 등) |
| **본인인증 화면** (SSO 부트스트랩) + **인증 여부 조회 API** | |

> 요약: SDK는 **"화면과 조회 수단"** 을 제공하고, **"토큰 수명 관리와 정책 판단"** 은 앱이 담당합니다.

## 요구사항

- iOS 16.0+

## 지원 기능

| 기능 | 지원 |
|------|------|
| 카카오 로그인 | ✅ |
| 네이버 로그인 | ✅ |
| 웹뷰 로그인 (구글·애플 포함) | ✅ |
| 마이페이지 (SSO 부트스트랩) | ✅ |
| **본인인증 (분리형)** | ✅ |
| **본인인증 여부 조회 API** | ✅ |

## 설치

### Swift Package Manager

`Package.swift`에 의존성을 추가합니다.

```swift
dependencies: [
    .package(url: "https://github.com/ZUM-Internet/ESTLoginKit-iOS", from: "2.0.0")
]
```

또는 Xcode에서 **File > Add Package Dependencies** 를 통해 URL을 입력해 추가할 수 있습니다.

## 핵심 개념 — 본인인증의 책임 분리

본인인증은 **두 가지를 명확히 분리**합니다.

| 구분 | 의미 | 담당 |
|------|------|------|
| **상태(fact)** | "이 사용자가 본인인증을 했는가?" — 백엔드가 아는 객관적 사실 | **SDK가 조회 API 제공** |
| **정책(policy)** | "지금 이 시점에 본인인증을 요구할까?" — 결제 직전? 글쓰기 직전? | **앱(호스트)이 결정** |

- 본인인증 화면을 **언제 띄울지(트리거)는 앱이 판단**합니다. SDK는 비즈니스 규칙을 갖지 않습니다.
- 판단의 근거가 되는 **인증 여부는 SDK의 `verificationStatus(...)`로 조회**합니다.
- 본인인증 **화면은 SDK가 제공**하고, **띄우기(present/sheet)는 앱이 담당**합니다. (SDK가 최상위 뷰를 찾아 present 하지 않습니다 — SwiftUI/UIKit 모두 자연스럽게 대응)

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
| `callbackURL` | `LoginWebView(callbackURL:)` / `ESTOneWebViewController(callbackURL:)` | `LoginWebView`는 `{baseURL}/auth/app-callback` 기본. 해당 URL로 리다이렉트되면 `code` 쿼리를 `ssoToken`으로 추출해 completion 호출. `nil` 명시 시 감지 비활성화 |
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

개발/스테이징 대응이 필요하면 `useEnvironment(_:)`로 환경을 지정합니다. 미지정 시 기본값은 `.production` 입니다. **웹 host와 API host가 환경에 따라 쌍으로 자동 결정**되므로 앱이 URL을 직접 넘기지 않습니다(불일치 방지).

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
                    Task { @MainActor in
                        _ = ESTLoginManager.shared.handle(url)
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
    return ESTLoginManager.shared.handle(url)
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

## 로그인

### 네이티브 로그인 (카카오 / 네이버)

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

성공 시 반환되는 `AuthResult`의 필드는 다음과 같습니다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `authorizeToken` | `String` | provider 액세스 토큰 |
| `refreshToken` | `String` | provider 리프레시 토큰 (카카오/네이버 모두 제공) |
| `ci` | `String` | 연계정보(CI). 네이버에서만 내려오며, 그 외에는 빈 문자열 |
| `email` | `String` | 이메일 |

> ⚠️ **`email`·`ci`는 빈 문자열(`""`)일 수 있습니다.**
> 두 값은 로그인 성공 직후 provider 프로필 API를 **1회 best-effort**로 조회해 채웁니다.
> Kakao Developers/네이버 개발자센터에서 해당 제공 항목(이메일·CI)이 활성화돼 있지 않거나
> 사용자가 동의를 거부하면 값이 내려오지 않으며, 이 경우에도 로그인은 **성공으로 처리**되고
> 해당 필드만 `""`가 됩니다. (email/ci 부재를 로그인 실패로 다루지 마세요.)

### 웹뷰 로그인

`LoginWebView`(SwiftUI) 또는 `ESTOneWebViewController`(UIKit)를 사용해 웹 기반 로그인을 구현할 수 있습니다.

웹뷰 로그인은 SSO 콜백 방식으로 동작하며, `completion` 클로저는 `(String?) -> Void` 타입입니다.

#### 로그인 URL 구성

SDK에서 로그인 URL을 생성할 수 있습니다. `initialize()` 시 전달한 `clientId`가 자동으로 포함됩니다. URL 빌더는 동기 메서드입니다(`await` 불필요).

```swift
// 기본 (redirect_url = {baseURL}/auth/app-callback)
let loginURL = ESTLoginManager.shared.loginURL()

// redirect_url 직접 지정
let loginURL = ESTLoginManager.shared.loginURL(redirectURL: "https://example.com/callback")

// state 전달 (선택)
let loginURL = ESTLoginManager.shared.loginURL(state: "https://m.zum.com")

// silent — AccountSwitcher를 건너뛰고 세션 쿠키가 유효할 때 ssoToken 자동 발급
// (비밀번호 변경 후 토큰 재발급용)
let loginURL = ESTLoginManager.shared.loginURL(silent: true)
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

#### 콜백 흐름

1. **SSO 콜백**: `callbackURL`로 리다이렉트되면 쿼리의 `code` 값을 `ssoToken`으로 추출하여 `completion(ssoToken)`을 호출합니다. `LoginWebView`의 기본값은 `ESTLoginManager.shared.appCallbackURL`(`{baseURL}/auth/app-callback`)이며, `nil`을 명시하면 이 감지는 비활성화됩니다.
2. **state URL 매칭 (ZUM 전용)**: 초기 URL의 `state` 쿼리 파라미터와 동일한 URL로 이동하면 `completion(nil)`을 호출합니다. 이 방식은 ZUM 서비스 전용이며, 일반적인 경우 SSO 콜백 방식을 사용하세요.

`LoginWebView`는 다음 시그니처를 가집니다.

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
> `LoginWebView` / `ESTOneWebViewController`는 화면 닫기를 직접 처리하지 않습니다.
> push, modal, custom transition 등 표시 방식에 따라 `completion` 클로저 안에서 직접 dismiss/pop을 구현하세요.

**SwiftUI**

```swift
.sheet(isPresented: $showWebView) {
    LoginWebView { ssoToken in
        if let ssoToken {
            print("SSO 토큰: \(ssoToken)")  // 토큰 교환은 호스트가 수행
        }
        showWebView = false
    }
    .ignoresSafeArea()
}
```

**UIKit (modal)** — UIKit은 `ESTOneWebViewController`를 직접 사용하며, `callbackURL`을 명시해야 SSO 콜백이 감지됩니다.

```swift
let vc = ESTOneWebViewController(
    url: ESTLoginManager.shared.loginURL(),
    callbackURL: ESTLoginManager.shared.appCallbackURL
) { [weak self] ssoToken in
    if let ssoToken {
        print("SSO 토큰: \(ssoToken)")
    }
    self?.dismiss(animated: true)
}
present(vc, animated: true)
```

**UIKit (push)**

```swift
let vc = ESTOneWebViewController(
    url: ESTLoginManager.shared.loginURL(),
    callbackURL: ESTLoginManager.shared.appCallbackURL
) { [weak self] _ in
    self?.navigationController?.popViewController(animated: true)
}
navigationController?.pushViewController(vc, animated: true)
```

#### 웹뷰 디버깅 (Safari Web Inspector)

`inspectable: true`를 전달하면 iOS 16.4 이상에서 Safari Web Inspector로 웹뷰를 디버깅할 수 있습니다. 기본값은 `false`입니다.

```swift
LoginWebView(inspectable: true) { ssoToken in
    showWebView = false
}
```

## 로그아웃

```swift
await ESTLoginManager.shared.logout()
```

- `logout()`은 각 provider 정리 실패를 던지지 않고 로깅만 하므로 **throw하지 않습니다** (`try` 불필요).
- 네이버/카카오 네이티브 토큰을 **각각 독립적으로(best-effort)** 삭제합니다. 한 provider 로그아웃이 실패해도 나머지 정리는 계속됩니다.
- **웹 세션(쿠키/스토리지)은 SDK가 건드리지 않습니다** — 웹 세션은 웹이 소유하며, est 웹뷰는 열 때마다 accessToken 부트스트랩으로 세션을 새로 검증·수립하므로 앱 로그아웃 시 로컬 웹 데이터를 지울 필요가 없습니다.
- 앱이 직접 저장한 accessToken/refreshToken(Keychain)은 **SDK가 보관하지 않으므로 호스트가 직접 삭제**해야 합니다. (SDK는 stateless)

> **네이버는 키체인에 토큰 정보를 저장합니다.**
> 네이버 로그인 SDK는 인증 토큰을 기기의 키체인에 보관하므로, 로그아웃 시점에 반드시 `logout()`을 호출하여 저장된 토큰을 제거해야 합니다.
> 호출하지 않으면 앱을 재설치하더라도 이전 토큰이 키체인에 남아 있을 수 있습니다.

## 마이페이지

마이페이지는 **SSO 부트스트랩 방식으로 여는 것을 권장**합니다. 유효한 accessToken만 넘기면
SDK가 ssoToken 발급 → SSO 부트스트랩 → 마이페이지 진입까지 처리하므로, 웹뷰 쿠키가 없거나
만료된 상태에서도 사용자가 로그인 화면을 다시 보지 않습니다.
(자세한 동작은 아래 [SSO 토큰](#sso-토큰-웹뷰-세션-수립) 참고)

**SwiftUI**

```swift
.sheet(isPresented: $showMyPage) {
    MyPageWebView(
        accessToken: accessToken,
        onPasswordChanged: { /* silent=true 로 토큰 재발급 */ },
        onAccountDeleted:  { /* 로그아웃 처리 */ },
        onError: { _ in showMyPage = false }  // ssoToken 발급 실패 (만료 토큰 등)
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

- `onPasswordChanged` / `onAccountDeleted`는 마이페이지에서 비밀번호 변경 / 회원 탈퇴 발생 시 호출되는 통지 콜백입니다. (실제 토큰 재발급·로그아웃 처리는 호스트 담당)

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

## 본인인증 (Identity Verification)

본인인증은 로그인/회원가입과 **완전히 분리**되어 있습니다. 앱은 (1) 인증 여부를 조회하고, (2) 필요할 때 본인인증 화면을 직접 띄웁니다.

> 상태 조회 API와 본인인증 화면(화면 URL / 완료 통지 방식 / 결과 필드) 스펙은 모두 확정·구현되었습니다.

### 1. 인증 여부 조회 — `verificationStatus`

SDK는 인증 상태를 동기적 사실로 조회하는 API만 제공합니다. **언제 호출할지/막을지는 앱이 결정**합니다.

```swift
public struct VerificationStatus {
    public let isVerified: Bool   // 응답 status == "CERTIFIED" 이면 true
}

extension ESTLoginManager {
    /// 회원 본인인증 상태를 조회합니다.
    /// - Parameter accessToken: 토큰 교환으로 발급받은 accessToken (SDK는 토큰을 보관하지 않으므로 호스트가 주입)
    public func verificationStatus(accessToken: String) async throws -> VerificationStatus
}
```

> **토큰은 SDK가 보관하지 않습니다(stateless).** 조회 시 호스트가 `accessToken`을 주입합니다.
> 내부적으로 다음을 호출합니다.
>
> ```http
> GET /members/v1/certification/status
> Authorization: Bearer {accessToken}
> ```
>
> 응답(공통): `{ "result": { "status": "CERTIFIED" | "UNCERTIFIED" }, "message": "" }`
> (`CERTIFIED`=완료, `UNCERTIFIED`=미인증이거나 존재하지 않는 회원). 인증 상태는 **통합회원 계정 단위**로
> 관리되어 모든 계열사에서 동일하게 조회됩니다.

### 2. 본인인증 화면

화면 콘텐츠는 SDK가 제공하고, **띄우기는 호스트**가 합니다. SwiftUI/UIKit 두 가지를 제공합니다.

**유효한 accessToken을 넘기는 방식을 권장**합니다 — SDK가 ssoToken 발급 → SSO 부트스트랩 →
본인인증 진입까지 처리하므로, 웹뷰 쿠키가 없거나 만료된 상태에서도 동작합니다.
발급 중에는 로딩 인디케이터가 표시되고, 실패(만료 토큰 등)하면 `onResult`로 `.failure`가 전달됩니다.

```swift
public struct VerificationResult {
    public let token: String       // 본인인증 후 재발급된 ssoToken
}

// SwiftUI — 권장 진입점
public struct IdentityVerificationView: View {
    public init(
        accessToken: String,          // 만료 판단·갱신은 앱 책임. 만료면 .failure(.server(statusCode: 401))
        callbackURL: String? = ESTLoginManager.shared.appCallbackURL,
        externalUserAgent: String? = nil,
        inspectable: Bool = false,
        onWebViewCreated: ((WKWebView) -> Void)? = nil,
        onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
    )

    // 세션 쿠키가 살아있을 때의 직접 진입 — url 생략 시 verificationURL(callbackURL:) 사용
    public init(url: URL? = nil, callbackURL: String? = ..., onResult: ...)
}

// UIKit — 동일한 진입점 구성 (accessToken / request / url)
public final class IdentityVerificationViewController: UIViewController {
    public init(accessToken: String, callbackURL: String? = ..., onResult: ...)
    public init(url: URL? = nil, callbackURL: String? = ..., onResult: ...)
}
```

목적지 URL은 `ESTLoginManager.shared.verificationURL(callbackURL:)`로 생성됩니다.

```
{webBaseURL}/webview/verification?client_id={클라이언트 ID}&callbackURL=<앱 콜백 URL, URL인코딩>
```

인증 회원 승격과 CI 충돌 해소는 웹뷰가 자체 처리합니다.
(세션 쿠키가 살아있으면 `url:` 직접 진입도 가능하며, 이때 임시 회원 세션이 그대로 전달됩니다)

**완료 통지는 ① 브릿지 → ② (브릿지 미등록 시) `callbackURL` 리다이렉트 순으로 실행되며, SDK가 둘 다 처리합니다.**
호스트는 `onResult`만 구현하면 되고, 두 경로가 모두 도착해도 결과는 **한 번만** 전달됩니다.

| 경로 | 형태 |
|------|------|
| 브릿지 | `window.webkit.messageHandlers.onVerificationComplete.postMessage(jsonString)` — 로그인용 `onLoginComplete`와 분리된 별도 메서드 |
| 페이로드 | `{ "status": "certified" \| "cancelled" \| "error", "token": "<ssoToken, certified일 때만>" }` |
| callbackURL | `<callbackURL>?status=certified\|cancelled\|error&code=<ssoToken>` |

| `status` | 의미 | `onResult` |
|----------|------|------------|
| `certified` | 승격 완료 (CI 충돌 시 계정 병합까지 완료) | `.success(VerificationResult)` |
| `cancelled` | 사용자가 본인인증 취소/중단 | `.failure(.cancelled)` |
| `error` | 승격 실패, 병합 실패, cert 조회 실패 등 | `.failure(.verificationFailed)` |

> ⚠️ **CI 충돌로 계정이 병합되면 웹뷰 안의 세션이 다른 계정으로 바뀌어 있을 수 있습니다.**
> `certified` 수신 시 호스트는 전달받은 `token`(ssoToken)으로 **세션을 재수립**해야 병합된 계정과 상태가 맞습니다.

### 3. 전체 흐름 — "필요한 시점에 본인인증"

본인인증이 필요한 시점(예: 결제 진입)에서 앱이 상태를 확인하고, 미인증이면 화면을 띄웁니다.

**SwiftUI**

```swift
struct CheckoutButton: View {
    @State private var showVerification = false

    var body: some View {
        Button("결제하기") {
            Task { await gateVerification() }
        }
        .sheet(isPresented: $showVerification) {
            IdentityVerificationView(accessToken: myAccessToken) { result in
                showVerification = false
                switch result {
                case .success(let v): proceedCheckout(verificationToken: v.token)
                case .failure(let error): handle(error)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func gateVerification() async {
        do {
            // 정책 판단은 앱이 — 여기서는 "미인증이면 막는다"
            let status = try await ESTLoginManager.shared.verificationStatus(accessToken: myAccessToken)
            if status.isVerified {
                proceedCheckout(verificationToken: nil)
            } else {
                showVerification = true
            }
        } catch {
            handle(error)
        }
    }
}
```

**UIKit**

```swift
func gateVerification() async {
    let status = try? await ESTLoginManager.shared.verificationStatus(accessToken: myAccessToken)
    guard status?.isVerified != true else { proceedCheckout(); return }

    let vc = IdentityVerificationViewController(accessToken: myAccessToken) { [weak self] result in
        self?.dismiss(animated: true)
        if case .success(let v) = result { self?.proceedCheckout(verificationToken: v.token) }
    }
    present(UINavigationController(rootViewController: vc), animated: true)
}
```

> 웹 브릿지(`onVerificationComplete`)를 우선 사용하므로 위 예시들처럼 `callbackURL`을 생략해도 결과가 전달됩니다.
> 브릿지가 없는 웹 환경을 대비해 콜백 URL 방식을 함께 쓰려면 `callbackURL`만 넘기면 됩니다. **처리 코드는 동일하며**,
> SDK가 `<callbackURL>?status=...&code=<ssoToken>` 리다이렉트를 가로채 같은 `onResult`로 전달합니다.
>
> ```swift
> IdentityVerificationView(
>     accessToken: myAccessToken,
>     callbackURL: "https://estoneid.com/auth/app-callback"
> ) { result in
>     // 브릿지로 오든 callbackURL로 오든 결과 처리는 동일
> }
> ```

### 4. 동작 정리

| 항목 | 동작 |
|------|------|
| 본인인증 트리거(언제 띄울지) | **호스트** (결제 직전 등 비즈니스 시점) |
| 인증 여부 조회 | `verificationStatus(accessToken:)` (SDK) |
| 인증 화면 제공 | `IdentityVerificationView` / `IdentityVerificationViewController` (SDK) |
| 화면 띄우기/닫기 | **호스트** (sheet/cover/present, dismiss도 호스트) |
| 토큰 | **호스트가 주입** (SDK 미보관) |
| 완료 통지 수신 | **SDK** (브릿지 + callbackURL 둘 다 처리, 결과는 1회만 전달) |
| 결과 | `Result<VerificationResult, AuthError>` |
| `certified` 후속 처리 | **호스트** (재발급된 ssoToken으로 세션 재수립) |

## 에러 처리

```swift
public enum AuthError: Error {
    case unsupportedPlatform
    case cancelled                   // 사용자 취소
    case notInitialized              // initialize(with:) 미호출
    case verificationFailed          // 본인인증 승격/병합 실패, 또는 완료 통지 해석 불가
    case server(statusCode: Int)     // 2xx가 아닌 응답
    case unknown(Error?)
}
```

- 네이티브 로그인(`login(with:)`)은 실패 시 각 provider SDK(`KakaoSDK` / `NidThirdPartyLogin`)의 원본 에러를 그대로 전달합니다. 상세 분류가 필요하면 카카오/네이버 공식 문서를 참고하세요.
- `verificationStatus(...)` / `issueSSOToken(...)` 등 REST API는 초기화 전 호출 시 `.notInitialized`, 2xx가 아닌 응답에 `.server(statusCode:)`를 던집니다. accessToken이 만료/무효면 `.server(statusCode: 401)`이므로 토큰 갱신 후 재시도하세요. 네트워크 오류는 `URLSession`의 원본 에러가 그대로 전파됩니다.
- 본인인증 화면(`onResult`)은 사용자 취소 시 `.failure(.cancelled)`, 승격/병합 실패 시 `.failure(.verificationFailed)`로 전달됩니다.

> **웹뷰 로그인의 completion**
> `LoginWebView` / `ESTOneWebViewController`의 `completion` 콜백은 `(String?) -> Void` 이며 에러를 던지지 않습니다.
> - `ssoToken`이 **non-nil**: `callbackURL`에서 `code` 쿼리 추출에 성공.
> - `ssoToken`이 **nil**: 초기 URL의 `state` 파라미터와 매칭되는 URL로 이동한 경우(ZUM 전용 흐름). 일반적인 경우 `callbackURL`을 전달해 non-nil 케이스로 성공을 판정하세요.

## 레퍼런스
- [Kakao developers](https://developers.kakao.com/docs/latest/ko/ios/getting-started#project)
- [Naver Login SDK iOS](https://developers.naver.com/docs/login/ios/ios.md)
