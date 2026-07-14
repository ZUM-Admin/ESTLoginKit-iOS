import Testing
@testable import ESTLoginKit

@Suite("LoginPlatform")
struct LoginPlatformTests {

    @Test("rawValue 검증")
    func rawValues() {
        #expect(LoginPlatform.kakao.rawValue == "kakao")
        #expect(LoginPlatform.naver.rawValue == "naver")
    }

    @Test("rawValue로 초기화")
    func initFromRawValue() {
        #expect(LoginPlatform(rawValue: "kakao") == .kakao)
        #expect(LoginPlatform(rawValue: "naver") == .naver)
        #expect(LoginPlatform(rawValue: "unknown") == nil)
    }
}
