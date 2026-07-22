# ESTLoginKit 예제 앱

`ESTLoginKit`을 실제 앱에 통합하는 방법을 보여주는 예제입니다. 네이티브 로그인(카카오·네이버),
웹뷰 로그인, 마이페이지, 본인인증, 그리고 호스트가 담당하는 토큰 교환·저장까지 end-to-end로 다룹니다.

## 실행 방법

1. `ESTLoginKit-iOS-Example.xcodeproj` 를 Xcode에서 엽니다.
   (SDK는 상위 폴더의 로컬 Swift Package로 자동 연결됩니다 — 별도 추가 불필요)
2. **`Config.local.xcconfig` 를 만들어 발급값을 붙여넣습니다.** (아래 참고)
3. 실행합니다.

## 설정 — `Config.local.xcconfig` 에 값만 넣으면 됩니다

시크릿은 소스 코드에 없습니다. 값은 **xcconfig → Info.plist(`$(VAR)` 치환) → 런타임(`ExampleConfig`)**
경로로 주입됩니다.

**실제 값은 추적되는 `Config.xcconfig`가 아니라, git이 무시하는 `Config.local.xcconfig`에 넣으세요.**
`Config.xcconfig` 맨 아래에서 이 파일을 선택적으로 include하며(뒤에 오므로 placeholder를 덮어씀),
덕분에 테스트하며 넣은 실제 시크릿이 실수로 커밋될 일이 없습니다.

```sh
# Example/ 에서
cp Config.xcconfig Config.local.xcconfig   # 시작 템플릿 복사 (Config.local.xcconfig는 .gitignore 처리됨)
# 이후 Config.local.xcconfig 의 YOUR_* 값을 실제 발급값으로 교체
```

> `Config.local.xcconfig` 가 없어도 빌드는 됩니다(로그인만 동작 안 함). 값 채우는 곳은 이 파일 한 곳뿐입니다.

| 키 | 설명 |
|------|------|
| `EST_CLIENT_ID` | ESTLoginKit에서 발급받은 클라이언트 ID (SDK 설정 + 토큰 교환 공통) |
| `EST_ENVIRONMENT` | 실행 환경: `test` \| `development` \| `production` |
| `EST_API_HOST` | 토큰 교환용 백엔드 API host (**scheme 제외**, 예: `test-api.estoneid.com`) |
| `KAKAO_APP_KEY` | 카카오 네이티브 앱 키 |
| `NAVER_APP_NAME` | 네이버 로그인 화면에 표시되는 앱 이름 |
| `NAVER_CLIENT_ID` / `NAVER_CLIENT_SECRET` | 네이버 앱 클라이언트 ID / Secret |
| `NAVER_URL_SCHEME` | 네이버 로그인 SDK용 URL Scheme |

> ⚠️ **xcconfig 주의:** 값에 `//`가 들어가면 주석으로 해석됩니다. 그래서 `EST_API_HOST`는
> `https://` 없이 host만 적고, 코드가 `https://`를 붙입니다.

URL Scheme(`kakao{앱키}`, `kakao{앱키}-{번들ID}`, 네이버 스킴)은 `Info.plist`가 위 값을 `$(VAR)`로
자동 참조하므로 **따로 등록할 필요가 없습니다.**

## 파일 구성

| 파일 | 설명 |
|------|------|
| `Config.local.xcconfig` | **여기에 실제 발급값을 넣습니다.** (git 미추적 — 유일한 수정 지점) |
| `Config.xcconfig` | placeholder 템플릿 (추적됨). 로컬 파일을 선택적 include |
| `ExampleConfig.swift` | Info.plist에서 설정값을 읽는 얇은 계층 |
| `ESTLoginKit_iOS_ExampleApp.swift` | 앱 진입점, `ESTLoginManager` 초기화 및 URL 핸들링 |
| `ContentView.swift` | 로그인·마이페이지·본인인증·토큰 관리 데모 UI |
| `EstoneAuth.swift` | ssoToken → access/refresh 토큰 교환·갱신 (**호스트 앱 책임** 영역 예시) |
