import Testing
@testable import ESTLoginKit

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
