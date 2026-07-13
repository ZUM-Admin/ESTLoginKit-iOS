# ESTLoginKit

iOS 소셜 로그인 · 마이페이지 · **본인인증**을 간편하게 통합할 수 있는 Swift Package입니다.

> 이 문서는 **본인인증(Identity Verification)이 회원가입 플로우에서 분리**되고, **본인인증 여부 조회 API**가 추가된 버전을 기준으로 작성되었습니다. 본인인증은 더 이상 로그인/회원가입에 묶여 있지 않으며, **사용하는 앱이 필요한 시점에 직접 호출**합니다.

> ## ⚠️ 토큰 관리는 이 SDK에서 하지 않습니다
>
> **ESTLoginKit은 stateless입니다.** 다음은 전부 **앱(호스트)의 책임**입니다:
> - `ssoToken` → `accessToken` / `refreshToken` **교환**
> - 토큰 **저장(Keychain)** · **갱신(refresh)** · **만료 처리**
> - 로그아웃 시 **앱이 저장한 토큰 삭제**
>
> SDK는 토큰을 **보관하지 않으며**, 토큰이 필요한 API(예: 본인인증 여부 조회)에는 **호출 시 호스트가 토큰을 주입**합니다.

## 한눈에 보기 — ESTLoginKit이 제공하는 것

| ✅ SDK가 제공 | 🙅 앱(호스트) 책임 |
|---|---|
| 카카오·네이버 **네이티브 로그인** | ssoToken → accessToken/refreshToken **교환** |
| **웹뷰 로그인 화면** (구글·애플 포함) + ssoToken 회수 | 토큰 **저장(Keychain)·갱신·만료** 처리 |
| **로그인 URL 빌더** (`loginURL`, `silent`) | 본인인증을 **언제 띄울지(정책)** |
| **마이페이지 화면** + 계정 이벤트 통지 콜백 | 화면 **present / dismiss** |
| **로그아웃** (네이티브 토큰 + 웹 세션 데이터 정리) | 로그인 결과 후속 처리(서버 통신 등) |
| **본인인증 화면** + **인증 여부 조회 API** | |

> 요약: SDK는 **"화면과 조회 수단"** 을 제공하고, **"토큰 수명 관리와 정책 판단"** 은 앱이 담당합니다.

## 요구사항

- iOS 16.0+
- Swift 5.7+
- Xcode 15+

## 지원 기능

| 기능 | 지원 |
|------|------|
| 카카오 로그인 | ✅ |
| 네이버 로그인 | ✅ |
| 웹뷰 로그인 (구글·애플 포함) | ✅ |
| 마이페이지 | ✅ |
| **본인인증 (분리형)** | ✅ |
| **본인인증 여부 조회 API** | ✅ |

## 설치

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ZUM-Internet/ESTLoginKit-iOS", from: "2.0.0")
]
```

또는 Xcode **File > Add Package Dependencies** 에서 URL로 추가합니다.

## 핵심 개념 — 본인인증의 책임 분리

본인인증은 **두 가지를 명확히 분리**합니다.

| 구분 | 의미 | 담당 |
|------|------|------|
| **상태(fact)** | "이 사용자가 본인인증을 했는가?" — 백엔드가 아는 객관적 사실 | **SDK가 조회 API 제공** |
| **정책(policy)** | "지금 이 시점에 본인인증을 요구할까?" — 결제 직전? 글쓰기 직전? | **앱(호스트)이 결정** |

- 본인인증 화면을 **언제 띄울지(트리거)는 앱이 판단**합니다. SDK는 비즈니스 규칙을 갖지 않습니다.
- 판단의 근거가 되는 **인증 여부는 SDK의 `verificationStatus(...)`로 조회**합니다.
- 본인인증 **화면은 SDK가 제공**하고, **띄우기(present/sheet)는 앱이 담당**합니다. (SDK가 최상위 뷰를 찾아 present 하지 않습니다 — SwiftUI/UIKit 모두 자연스럽게 대응)

## 설정

### 1. 초기화

앱 진입점에서 한 번 초기화합니다.

```swift
import ESTLoginKit

let config = ESTLoginConfiguration.Builder(clientId: "YOUR_CLIENT_ID")
    .useEnvironment(.development)   // 기본값 .production
    .useKakao(KakaoConfiguration(appKey: "YOUR_KAKAO_NATIVE_APP_KEY"))
    .useNaver(NaverConfiguration(appName: "앱이름", clientID: "CLIENT_ID", clientSecret: "SECRET", urlScheme: "YOUR_SCHEME"))
    .build()

await ESTLoginManager.shared.initialize(with: config)
```

- 실행 환경은 `.useEnvironment(.development)` / `.useEnvironment(.production)`로 지정합니다. (기본값 `.production`)
- **웹 host와 API host가 환경에 따라 쌍으로 자동 결정**되므로 앱이 URL을 직접 넘기지 않습니다(불일치 방지).
- URL 핸들링(`onOpenURL` / `application(_:open:)`), `Info.plist`(`LSApplicationQueriesSchemes`), 커스텀 URL 스킴 설정은 기존 README와 동일합니다.

> 환경별 host (`ESTEnvironment`가 소유):
> | 환경 | 로그인 웹 | API |
> |------|-----------|-----|
> | `.production` | `https://estoneid.com` | `https://api.estoneid.com` |
> | `.development` | `https://dev.estoneid.com` | `https://dev-api.estoneid.com` |

## 로그인

### 네이티브 로그인 (카카오 / 네이버)

```swift
do {
    let result = try await ESTLoginManager.shared.login(with: .kakao)
    print("토큰: \(result.authorizeToken)")
} catch {
    print("로그인 실패: \(error)")
}
```

### 웹뷰 로그인

`LoginWebView`(SwiftUI) 또는 `ESTOneWebViewController`(UIKit)를 사용합니다. `url`은 기본값으로 `loginURL()`이 들어가 생략 가능합니다.

```swift
.sheet(isPresented: $showWebView) {
    LoginWebView(callbackURL: "https://estoneid.com/auth/app-callback") { ssoToken in
        if let ssoToken { /* 토큰 교환은 호스트가 수행 */ }
        showWebView = false
    }
    .ignoresSafeArea()
}
```

> URL 빌더는 동기 메서드입니다. `ESTLoginManager.shared.loginURL(redirectURL:state:silent:)` (await 불필요)
> - `silent: true` → AccountSwitcher를 건너뛰고 세션 쿠키가 유효할 때 ssoToken을 자동 발급 (비밀번호 변경 후 재발급용)

## 로그아웃

```swift
try await ESTLoginManager.shared.logout()
```

- 네이버/카카오 토큰 삭제와 **웹 세션 데이터(쿠키 + localStorage 등) 삭제**를 **각각 독립적으로(best-effort)** 수행합니다. 한 provider 로그아웃이 실패해도 나머지 정리는 계속됩니다.
- 앱이 직접 저장한 accessToken/refreshToken(Keychain)은 **SDK가 보관하지 않으므로 호스트가 직접 삭제**해야 합니다. (SDK는 stateless)

## 마이페이지

`MyPageWebView`(SwiftUI) 또는 `ESTOneWebViewController`(UIKit)로 진입합니다. 로그인 세션 쿠키를 공유하므로 별도 인증 없이 접근됩니다. `url` 기본값은 `mypageURL`입니다.

```swift
.sheet(isPresented: $showMyPage) {
    MyPageWebView(
        onPasswordChanged: { /* silent=true 로 토큰 재발급 */ },
        onAccountDeleted:  { /* 로그아웃 처리 */ }
    )
    .ignoresSafeArea()
}
```

- `onPasswordChanged` / `onAccountDeleted`는 마이페이지에서 비밀번호 변경 / 회원 탈퇴 발생 시 호출되는 통지 콜백입니다. (실제 토큰 재발급·로그아웃 처리는 호스트 담당)

---

## 본인인증 (Identity Verification)

본인인증은 로그인/회원가입과 **완전히 분리**되어 있습니다. 앱은 (1) 인증 여부를 조회하고, (2) 필요할 때 본인인증 화면을 직접 띄웁니다.

> 상태 조회 API와 본인인증 화면(화면 URL / 완료 통지 방식 / 결과 필드) 스펙은 모두 확정·구현되었습니다.
> 다만 `VerificationResult`에 `ci`/`di` 등 추가 필드를 넣을지는 아직 정해지지 않았습니다.

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

```swift
public struct VerificationResult {
    public let token: String       // 본인인증 후 재발급된 ssoToken
}

// SwiftUI — url 생략 시 verificationURL(callbackURL:)이 사용됩니다.
public struct IdentityVerificationView: UIViewControllerRepresentable {
    public init(
        url: URL? = nil,
        callbackURL: String? = nil,   // 브릿지 미등록 시 리다이렉트될 앱 콜백 URL (선택)
        externalUserAgent: String? = nil,
        inspectable: Bool = false,
        onWebViewCreated: ((WKWebView) -> Void)? = nil,
        onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
    )
}

// UIKit
public final class IdentityVerificationViewController: UIViewController {
    public init(
        url: URL? = nil,
        callbackURL: String? = nil,
        externalUserAgent: String? = nil,
        inspectable: Bool = false,
        onWebViewCreated: ((WKWebView) -> Void)? = nil,
        onResult: @escaping (Result<VerificationResult, AuthError>) -> Void
    )
}
```

화면 URL은 `ESTLoginManager.shared.verificationURL(callbackURL:)`로 생성됩니다.

```
{webBaseURL}/webview/verification?callbackURL=<앱 콜백 URL, URL인코딩>
```

로그인 세션 쿠키(`WKWebsiteDataStore.default()`)를 공유하므로 임시 회원 세션이 그대로 전달되며,
인증 회원 승격과 CI 충돌 해소는 웹뷰가 자체 처리합니다.

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
            IdentityVerificationView { result in        // url·callbackURL 생략 = 브릿지로 결과 수신
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

    let vc = IdentityVerificationViewController { [weak self] result in
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
> IdentityVerificationView(callbackURL: "https://estoneid.com/auth/app-callback") { result in
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

- 네이티브 로그인(`login(with:)`)은 실패 시 각 provider SDK의 원본 에러를 전달합니다.
- `verificationStatus(...)`는 초기화 전 호출 시 `.notInitialized`, 2xx가 아닌 응답에 `.server(statusCode:)`를 던집니다. accessToken이 만료/무효면 `.server(statusCode: 401)`이므로 토큰 갱신 후 재시도하세요. 네트워크 오류는 `URLSession`의 원본 에러가 그대로 전파됩니다.
- 본인인증 화면(`onResult`)은 사용자 취소 시 `.failure(.cancelled)`, 승격/병합 실패 시 `.failure(.verificationFailed)`로 전달됩니다.

## 레퍼런스
- [Kakao developers](https://developers.kakao.com/docs/latest/ko/ios/getting-started#project)
- [Naver Login SDK iOS](https://developers.naver.com/docs/login/ios/ios.md)
