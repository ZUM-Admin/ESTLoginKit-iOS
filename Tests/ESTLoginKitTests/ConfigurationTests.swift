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
            .build()

        #expect(config.kakaoConfig?.appKey == "kakao_key")
        #expect(config.naverConfig?.clientID == "naver_id")
    }

    @Test("빌더 반환 타입 확인 - 체이닝 가능")
    func builderReturnsBuilder() {
        let builder = ESTLoginConfiguration.Builder()
        let returnedBuilder = builder.useKakao(nil)
        #expect(returnedBuilder === builder)
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
