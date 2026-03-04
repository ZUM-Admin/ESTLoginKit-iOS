# ESTLoginKitExample

ESTLoginKit을 실제 앱에 통합하는 방법을 보여주는 예제 프로젝트입니다.

## Xcode 프로젝트 생성 방법

1. Xcode에서 **File > New > Project** → iOS App 선택
2. Product Name: `ESTLoginKitExample`, Interface: SwiftUI, Language: Swift
3. 생성 후 기본 `ContentView.swift`, `[AppName]App.swift` 파일을 이 폴더의 파일로 교체

## 패키지 추가

**File > Add Package Dependencies** 에서 ESTLoginKit 로컬 패키지 추가:
- 경로: `../` (ESTLoginKit 루트 디렉토리)

## 필수 설정

### Info.plist

```xml
<!-- 카카오 URL Scheme -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>storykompassauth</string>
    <string>kakaolink</string>
</array>

<!-- 카카오 앱 키 -->
<key>KAKAO_APP_KEY</key>
<string>YOUR_KAKAO_APP_KEY</string>

<!-- 구글 클라이언트 ID -->
<key>GIDClientID</key>
<string>YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com</string>

<!-- 구글 역방향 클라이언트 ID (URL Scheme) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID</string>
            <string>kakao${KAKAO_APP_KEY}</string>
            <string>YOUR_NAVER_URL_SCHEME</string>
        </array>
    </dict>
</array>
```

### Signing & Capabilities

- **Sign in with Apple** Capability 추가 (Apple 로그인 사용 시)

## 파일 구성

| 파일 | 설명 |
|------|------|
| `ESTLoginKitExampleApp.swift` | 앱 진입점, ESTLoginManager 초기화 및 URL 핸들링 |
| `LoginViewModel.swift` | 로그인 로직 및 상태 관리 |
| `ContentView.swift` | 로그인 UI (카카오 / 네이버 / 구글 / Apple 버튼) |
