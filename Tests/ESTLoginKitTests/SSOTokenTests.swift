import Foundation
import Testing
@testable import ESTLoginKit

// MARK: - SSO 부트스트랩 URL

@Suite("SSO 부트스트랩 URL")
struct SSOLoginURLTests {

    @Test("GET /auth/sso-login + code + redirect_url 쿼리")
    func buildsBootstrapURL() {
        let url = ESTLoginManager.ssoLoginURL(redirectURL: "/mypage/setting", ssoToken: "abc123")

        #expect(url.path == "/auth/sso-login")
        #expect(url.queryValue(for: "code") == "abc123")
        #expect(url.queryValue(for: "redirect_url") == "/mypage/setting")
    }

    @Test("redirect_url 생략 시 code만 담긴다 (웹이 홈으로 이동)")
    func omitsRedirectURLWhenNil() {
        let url = ESTLoginManager.ssoLoginURL(redirectURL: nil, ssoToken: "abc123")

        #expect(url.queryValue(for: "code") == "abc123")
        #expect(url.queryValue(for: "redirect_url") == nil)
    }

    @Test("쿼리 있는 redirect_url이 값 그대로 왕복된다")
    func redirectURLWithQuery() {
        let redirect = "/auth/verification?client_id=4870426&callbackURL=https://x.com/cb"
        let url = ESTLoginManager.ssoLoginURL(redirectURL: redirect, ssoToken: "sso")
        // 인코딩이 깨지면 redirect_url 안의 &callbackURL이 최상위 쿼리로 새어나온다.
        #expect(url.queryValue(for: "redirect_url") == redirect)
        #expect(url.queryValue(for: "callbackURL") == nil)
        #expect(url.queryValue(for: "client_id") == nil)
    }

    @Test("토큰 특수문자(+ = /)는 퍼센트 인코딩된다")
    func encodesTokenSpecialCharacters() {
        // +를 그대로 두면 서버가 공백으로 해석한다 (AES256 토큰은 + = / 포함 가능)
        let url = ESTLoginManager.ssoLoginURL(redirectURL: nil, ssoToken: "AES+base64/pad==")

        #expect(url.absoluteString.contains("code=AES%2Bbase64%2Fpad%3D%3D"))
        #expect(url.queryValue(for: "code") == "AES+base64/pad==")
    }

    @Test("redirect_url은 목적지 경로 전체가 1회 인코딩된다 (가이드 예시)")
    func encodesRedirectURLOnce() {
        let redirect = "/auth/verification?client_id=8941192&callbackURL=https://test.estoneid.com/auth/app-callback"
        let url = ESTLoginManager.ssoLoginURL(redirectURL: redirect, ssoToken: "sso")

        let encoded = url.absoluteString.components(separatedBy: "redirect_url=").last
        #expect(encoded == "%2Fauth%2Fverification%3Fclient_id%3D8941192%26callbackURL%3Dhttps%3A%2F%2Ftest.estoneid.com%2Fauth%2Fapp-callback")
    }

    @Test("redirect_url 값 추출 — path와 query 유지")
    func redirectURLValueFromURL() {
        let url = URL(string: "https://test.estoneid.com/auth/verification?client_id=1")!
        #expect(ESTLoginManager.redirectURLValue(from: url) == "/auth/verification?client_id=1")
    }

    @Test("쿼리 없는 URL의 redirect_url은 path만")
    func redirectURLValueWithoutQuery() {
        let url = URL(string: "https://test.estoneid.com/mypage/setting")!
        #expect(ESTLoginManager.redirectURLValue(from: url) == "/mypage/setting")
    }
}

// MARK: - 임의 경로 부트스트랩

@Suite("임의 경로 redirect_url 정규화")
struct RedirectPathNormalizationTests {

    @Test("내부 경로는 그대로 쓰인다")
    func keepsAbsolutePath() {
        #expect(ESTLoginManager.redirectURLValue(from: "/mypage/pointhistory") == "/mypage/pointhistory")
    }

    @Test("앞의 슬래시가 없으면 붙인다")
    func prependsLeadingSlash() {
        // 웹은 `/`로 시작하는 내부 경로만 목적지로 인정한다
        #expect(ESTLoginManager.redirectURLValue(from: "mypage/pointhistory") == "/mypage/pointhistory")
    }

    @Test("경로의 자체 쿼리는 보존된다")
    func keepsQueryOfPath() {
        #expect(ESTLoginManager.redirectURLValue(from: "/mypage/pointhistory?tab=1") == "/mypage/pointhistory?tab=1")
    }

    @Test("절대 URL을 넘기면 path + query만 취한다")
    func stripsSchemeAndHost() {
        let path = ESTLoginManager.redirectURLValue(from: "https://test.estoneid.com/mypage/pointhistory?tab=1")
        #expect(path == "/mypage/pointhistory?tab=1")
    }

    @Test("정규화된 경로가 부트스트랩 URL에 1회 인코딩되어 실린다")
    func buildsBootstrapURLWithPath() {
        let url = ESTLoginManager.ssoLoginURL(
            redirectURL: ESTLoginManager.redirectURLValue(from: "/mypage/pointhistory?tab=1"),
            ssoToken: "sso"
        )

        #expect(url.path == "/auth/sso-login")
        #expect(url.queryValue(for: "redirect_url") == "/mypage/pointhistory?tab=1")
        // 인코딩이 깨지면 경로 안의 tab이 최상위 쿼리로 새어나온다
        #expect(url.queryValue(for: "tab") == nil)
    }
}
