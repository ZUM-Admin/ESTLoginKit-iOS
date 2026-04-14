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

예제 코드의 placeholder는 실제 값으로 교체해야 동작합니다.

| Placeholder | 설명 |
|------|------|
| `YOUR_CLIENT_ID` | ESTLoginKit에서 발급받은 클라이언트 ID |
| `KAKAO_SDK_KEY` | 카카오 네이티브 앱 키 |
| `NAVER_CLIENT_ID` / `NAVER_CLIENT_SECRET` | 네이버 앱 클라이언트 ID / Secret |
| `NAVER_URL_SCHEME` | 네이버 로그인 SDK용 URL Scheme |
| `YOUR_APP_NAME` | 네이버 로그인 화면에 표시되는 앱 이름 |
| `YOUR_CALLBACK_URL` | 로그인 완료 시 리다이렉트되는 콜백 URL |

### Info.plist

```xml
<!-- 카카오 / 네이버 URL Scheme 질의 -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>storykompassauth</string>
    <string>kakaolink</string>
    <string>naversearchapp</string>
    <string>naversearchthirdlogin</string>
</array>

<!-- URL Scheme 등록 -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>kakaoKAKAO_SDK_KEY</string>
            <string>NAVER_URL_SCHEME</string>
        </array>
    </dict>
</array>
```

> 카카오 네이티브 앱 키가 `abc123`이라면 URL Scheme은 `kakaoabc123` 형식으로 등록합니다.

## 파일 구성

| 파일 | 설명 |
|------|------|
| `ESTLoginKitExampleApp.swift` | 앱 진입점, ESTLoginManager 초기화 및 URL 핸들링 |
| `LoginViewModel.swift` | 로그인 로직 및 상태 관리 |
| `ContentView.swift` | 로그인 UI (카카오 / 네이버 / 웹뷰 로그인 버튼) |
