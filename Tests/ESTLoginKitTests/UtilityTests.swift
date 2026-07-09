import Testing
import Foundation
@testable import ESTLoginKit

@Suite("Encodable.jsonString")
struct EncodableJSONStringTests {

    private struct Dummy: Encodable, Decodable {
        let name: String
        let value: Int
    }

    @Test("정상 인코딩 시 nil이 아님")
    func jsonStringNotNil() {
        let dummy = Dummy(name: "test", value: 42)
        #expect(dummy.jsonString != nil)
    }

    @Test("올바른 JSON 키/값 포함")
    func jsonStringContainsFields() {
        let dummy = Dummy(name: "hello", value: 7)
        let json = dummy.jsonString ?? ""
        #expect(json.contains("\"name\""))
        #expect(json.contains("\"hello\""))
        #expect(json.contains("\"value\""))
        #expect(json.contains("7"))
    }

    @Test("유효한 JSON으로 재파싱 가능")
    func jsonStringRoundtrip() throws {
        let dummy = Dummy(name: "roundtrip", value: 99)
        let json = try #require(dummy.jsonString)
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(Dummy.self, from: data)
        #expect(decoded.name == dummy.name)
        #expect(decoded.value == dummy.value)
    }
}

@Suite("URL.queryValue")
struct URLQueryValueTests {

    @Test("값이 있으면 그대로 반환")
    func returnsValue() throws {
        let url = try #require(URL(string: "https://est.com/cb?code=ABC123"))
        #expect(url.queryValue(for: "code") == "ABC123")
    }

    @Test("빈 값은 nil이 아닌 빈 문자열로 반환된다")
    func emptyValueIsEmptyStringNotNil() throws {
        let url = try #require(URL(string: "https://est.com/cb?code="))
        #expect(url.queryValue(for: "code") == "")
    }

    @Test("파라미터가 없으면 nil")
    func missingParameterIsNil() throws {
        let url = try #require(URL(string: "https://est.com/cb?state=xyz"))
        #expect(url.queryValue(for: "code") == nil)
    }
}

@Suite("URL.nonEmptyQueryValue")
struct URLNonEmptyQueryValueTests {

    @Test("값이 있으면 그대로 반환")
    func returnsValue() throws {
        let url = try #require(URL(string: "https://est.com/cb?code=ABC123"))
        #expect(url.nonEmptyQueryValue(for: "code") == "ABC123")
    }

    @Test("빈 값은 nil로 취급")
    func emptyValueIsNil() throws {
        let url = try #require(URL(string: "https://est.com/cb?code="))
        #expect(url.nonEmptyQueryValue(for: "code") == nil)
    }

    @Test("값 없는 파라미터는 nil")
    func valuelessParameterIsNil() throws {
        let url = try #require(URL(string: "https://est.com/cb?code"))
        #expect(url.nonEmptyQueryValue(for: "code") == nil)
    }

    @Test("파라미터가 없으면 nil")
    func missingParameterIsNil() throws {
        let url = try #require(URL(string: "https://est.com/cb?state=xyz"))
        #expect(url.nonEmptyQueryValue(for: "code") == nil)
    }

    @Test("쿼리 자체가 없으면 nil")
    func noQueryIsNil() throws {
        let url = try #require(URL(string: "https://est.com/cb"))
        #expect(url.nonEmptyQueryValue(for: "code") == nil)
    }
}

/// ESTOneWebViewController가 리다이렉트 체인에서 code를 캡처하는 규칙을 재현한다.
/// (컨트롤러의 캡처 로직이 private이라 동일한 규칙을 여기서 검증한다.)
@Suite("ssoToken 캡처 규칙")
struct SSOTokenCaptureRuleTests {

    /// 네비게이션 URL을 순서대로 흘려보내며 캡처된 최종 code를 돌려준다.
    private func capture(_ urls: [String]) -> String? {
        var ssoToken: String?
        for string in urls {
            guard let url = URL(string: string) else { continue }
            if let code = url.nonEmptyQueryValue(for: "code") {
                ssoToken = code
            }
        }
        return ssoToken
    }

    @Test("재시도 체인에서 최신 code로 갱신된다")
    func latestCodeWins() {
        #expect(capture([
            "https://est.com/auth?code=OLD",
            "https://est.com/retry?code=NEW",
        ]) == "NEW")
    }

    @Test("빈 code는 기존 값을 덮어쓰지 않는다")
    func emptyCodeDoesNotClobber() {
        #expect(capture([
            "https://est.com/auth?code=GOOD",
            "https://est.com/interstitial?code=",
        ]) == "GOOD")
    }

    @Test("code 없는 URL은 기존 값을 덮어쓰지 않는다")
    func missingCodeDoesNotClobber() {
        #expect(capture([
            "https://est.com/auth?code=GOOD",
            "https://est.com/interstitial",
            "https://est.com/cb?state=xyz",
        ]) == "GOOD")
    }

    @Test("code를 한 번도 못 만나면 nil")
    func neverCapturedIsNil() {
        #expect(capture([
            "https://est.com/auth",
            "https://est.com/cb?code=",
        ]) == nil)
    }
}
