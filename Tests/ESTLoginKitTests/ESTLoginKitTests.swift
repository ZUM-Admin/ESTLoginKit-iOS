import Testing
import Foundation
@testable import ESTLoginKit

// MARK: - ESTLoginConfiguration.Builder

@Suite("ESTLoginConfiguration Builder")
struct ESTLoginConfigurationBuilderTests {

    @Test("기본 빌더 - 모든 설정이 비활성화")
    func defaultBuilder() {
        let config = ESTLoginConfiguration.Builder().build()

        #expect(config.kakaoConfig == nil)
        #expect(config.naverConfig == nil)
        #expect(config.isGoogleEnabled == false)
        #expect(config.isAppleEnabled == false)
    }

    @Test("카카오 설정 추가")
    func useKakao() {
        let kakaoConfig = KakaoConfiguration(appKey: "test_kakao_key")
        let config = ESTLoginConfiguration.Builder()
            .useKakao(kakaoConfig)
            .build()

        #expect(config.kakaoConfig?.appKey == "test_kakao_key")
    }

    @Test("카카오 설정 nil 제거")
    func useKakaoNil() {
        let config = ESTLoginConfiguration.Builder()
            .useKakao(nil)
            .build()

        #expect(config.kakaoConfig == nil)
    }

    @Test("네이버 설정 추가")
    func useNaver() {
        let naverConfig = NaverConfiguration(
            appName: "TestApp",
            clientID: "client_id",
            clientSecret: "client_secret",
            urlScheme: "navertestapp"
        )
        let config = ESTLoginConfiguration.Builder()
            .useNaver(naverConfig)
            .build()

        #expect(config.naverConfig?.appName == "TestApp")
        #expect(config.naverConfig?.clientID == "client_id")
        #expect(config.naverConfig?.clientSecret == "client_secret")
        #expect(config.naverConfig?.urlScheme == "navertestapp")
    }

    @Test("구글 활성화")
    func useGoogle() {
        let config = ESTLoginConfiguration.Builder()
            .useGoogle()
            .build()

        #expect(config.isGoogleEnabled == true)
    }

    @Test("애플 활성화")
    func useApple() {
        let config = ESTLoginConfiguration.Builder()
            .useApple()
            .build()

        #expect(config.isAppleEnabled == true)
    }

    @Test("모든 설정 체이닝")
    func buildWithAllOptions() {
        let config = ESTLoginConfiguration.Builder()
            .useKakao(KakaoConfiguration(appKey: "kakao_key"))
            .useNaver(NaverConfiguration(
                appName: "App",
                clientID: "naver_id",
                clientSecret: "naver_secret",
                urlScheme: "naverapp"
            ))
            .useGoogle()
            .useApple()
            .build()

        #expect(config.kakaoConfig?.appKey == "kakao_key")
        #expect(config.naverConfig?.clientID == "naver_id")
        #expect(config.isGoogleEnabled == true)
        #expect(config.isAppleEnabled == true)
    }

    @Test("빌더 반환 타입 확인 - 체이닝 가능")
    func builderReturnsBuilder() {
        let builder = ESTLoginConfiguration.Builder()
        let returnedBuilder = builder.useGoogle()
        // 같은 빌더 인스턴스를 반환해야 체이닝이 가능
        #expect(returnedBuilder === builder)
    }
}

// MARK: - LoginPlatform

@Suite("LoginPlatform")
struct LoginPlatformTests {

    @Test("rawValue 검증")
    func rawValues() {
        #expect(LoginPlatform.kakao.rawValue == "kakao")
        #expect(LoginPlatform.naver.rawValue == "naver")
        #expect(LoginPlatform.google.rawValue == "google")
        #expect(LoginPlatform.apple.rawValue == "apple")
    }

    @Test("rawValue로 초기화")
    func initFromRawValue() {
        #expect(LoginPlatform(rawValue: "kakao") == .kakao)
        #expect(LoginPlatform(rawValue: "naver") == .naver)
        #expect(LoginPlatform(rawValue: "google") == .google)
        #expect(LoginPlatform(rawValue: "apple") == .apple)
        #expect(LoginPlatform(rawValue: "unknown") == nil)
    }
}

// MARK: - KakaoConfiguration

@Suite("KakaoConfiguration")
struct KakaoConfigurationTests {

    @Test("appKey 저장")
    func appKeyStored() {
        let config = KakaoConfiguration(appKey: "my_app_key")
        #expect(config.appKey == "my_app_key")
    }
}

// MARK: - NaverConfiguration

@Suite("NaverConfiguration")
struct NaverConfigurationTests {

    @Test("모든 필드 저장")
    func allFieldsStored() {
        let config = NaverConfiguration(
            appName: "MyApp",
            clientID: "my_client_id",
            clientSecret: "my_secret",
            urlScheme: "myapp"
        )

        #expect(config.appName == "MyApp")
        #expect(config.clientID == "my_client_id")
        #expect(config.clientSecret == "my_secret")
        #expect(config.urlScheme == "myapp")
    }
}

// MARK: - Mock AuthProvider

@Suite("AuthProvider (Mock)")
struct MockAuthProviderTests {

    private struct MockSuccessProvider: AuthProvider {
        let token: String
        func login() async throws -> String { token }
    }

    private struct MockFailureProvider: AuthProvider {
        let error: Error
        func login() async throws -> String { throw error }
    }

    @Test("성공 시 토큰 반환")
    func successReturnsToken() async throws {
        let provider = MockSuccessProvider(token: "mock_token_123")
        let result = try await provider.login()
        #expect(result == "mock_token_123")
    }

    @Test("실패 시 에러 throw")
    func failureThrowsError() async {
        let provider = MockFailureProvider(error: AuthError.unknown(nil))
        await #expect(throws: (any Error).self) {
            _ = try await provider.login()
        }
    }

    @Test("AuthError.unknown 에러 전파")
    func unknownErrorPropagated() async throws {
        let provider = MockFailureProvider(error: AuthError.unknown(nil))
        do {
            _ = try await provider.login()
            Issue.record("에러가 발생해야 합니다")
        } catch let error as AuthError {
            if case .unknown = error { /* 통과 */ } else {
                Issue.record("AuthError.unknown이어야 합니다")
            }
        }
    }
}

// MARK: - AuthError

@Suite("AuthError")
struct AuthErrorTests {

    @Test("unsupportedPlatform은 Error 프로토콜 채택")
    func unsupportedPlatformIsError() {
        let error: any Error = AuthError.unsupportedPlatform
        #expect(error is AuthError)
    }

    @Test("unknown(nil) 생성")
    func unknownNil() {
        let error = AuthError.unknown(nil)
        if case .unknown(let wrapped) = error {
            #expect(wrapped == nil)
        } else {
            Issue.record("AuthError.unknown이어야 합니다")
        }
    }

    @Test("unknown(error) - 원인 에러 래핑")
    func unknownWithCause() {
        let cause = NSError(domain: "TestDomain", code: 42)
        let error = AuthError.unknown(cause)
        if case .unknown(let wrapped) = error {
            #expect((wrapped as? NSError)?.code == 42)
        } else {
            Issue.record("AuthError.unknown이어야 합니다")
        }
    }
}
