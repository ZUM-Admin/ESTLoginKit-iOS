# ESTLoginKit

iOS 소셜 로그인을 간편하게 통합할 수 있는 Swift Package입니다.

## 요구사항

- iOS 16.0+
- Swift 6.2+
- Xcode 16+

## 지원 플랫폼

| 플랫폼 | 지원 여부 |
|--------|----------|
| 카카오 | ✅ |
| 네이버 | ✅ |
| 구글   | ✅ |
| 애플   | ✅ |

## 설치

### Swift Package Manager

`Package.swift`에 의존성을 추가합니다.

```swift
dependencies: [
    .package(url: "https://github.com/your-org/ESTLoginKit", from: "1.0.0")
]
```

또는 Xcode에서 **File > Add Package Dependencies** 를 통해 URL을 입력해 추가할 수 있습니다.

## 설정

### 1. 초기화

앱 시작 시점(`AppDelegate` 또는 `@main` 진입점)에서 SDK를 초기화합니다.

```swift
import ESTLoginKit

let config = ESTLoginConfiguration.Builder()
    .useKakao(KakaoConfiguration(appKey: "YOUR_KAKAO_NATIVE_APP_KEY"))
    .useNaver(NaverConfiguration(appName: "앱이름", clientID: "CLIENT_ID", clientSecret: "SECRET", urlScheme: "YOUR_SCHEME"))
    .useGoogle() // GIDClientID는 Info.plist에서 자동으로 읽습니다
    .useApple()  // Xcode Capability 설정만으로 활성화됩니다
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

<!-- 구글 -->
<key>GIDClientID</key>
<string>YOUR_GOOGLE_CLIENT_ID</string>
```

### 4. 커스텀 URL 스킴

** 카카오 **
서비스 앱 실행을 위해 커스텀 URL 스킴 설정을 합니다.
[Info] > [URL Types] > [URL Schemes] 항목에 네이티브 앱 키(Native App Key)를 kakao${NATIVE_APP_KEY} 형식으로 등록합니다.
예를 들어 네이티브 앱 키가 "123456789"라면 [URL Schemes]에 "kakao123456789"를 입력합니다.

** 네이버 **

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

** 구글 **
Google Cloud Console에서 OAuth 클라이언트 ID를 생성하면 `GoogleService-Info.plist`를 다운로드할 수 있습니다.
해당 파일의 `REVERSED_CLIENT_ID` 값을 [Info] > [URL Types] > [URL Schemes]에 등록합니다.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

`REVERSED_CLIENT_ID`는 `GoogleService-Info.plist` 내에서 확인하거나, Google Cloud Console > OAuth 2.0 클라이언트 ID 상세 페이지의 **iOS URL 스킴** 항목에서 복사할 수 있습니다.

** 애플 **
Sign in with Apple은 외부 SDK나 Info.plist 수정 없이 Xcode Capability 추가만으로 설정할 수 있습니다.

1. Xcode에서 앱 타겟 선택
2. **Signing & Capabilities** 탭으로 이동
3. **+ Capability** 버튼 클릭
4. **Sign in with Apple** 추가

## 사용법

```swift
import ESTLoginKit

do {
    let accessToken = try await ESTLoginManager.shared.login(with: .kakao)
    print("로그인 성공: \(accessToken)")
} catch AuthError.unsupportedPlatform {
    print("지원하지 않는 플랫폼입니다.")
} catch {
    print("로그인 실패: \(error)")
}
```

## 에러 처리

| 에러 | 설명 |
|------|------|
| `AuthError.unsupportedPlatform` | 아직 구현되지 않은 플랫폼으로 로그인 시도 |
| `AuthError.unknown(Error?)` | 알 수 없는 오류 |

## 레퍼런스
- [Kakao developers](https://developers.kakao.com/docs/latest/ko/ios/getting-started#project)
- [Naver Login SDK iOS](https://developers.naver.com/docs/login/ios/ios.md)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Sign in with Apple](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple)
