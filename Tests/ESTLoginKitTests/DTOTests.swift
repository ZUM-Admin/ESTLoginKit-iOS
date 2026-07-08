import Testing
import Foundation
@testable import ESTLoginKit

// MARK: - RequestLoginDTO

@Suite("RequestLoginDTO")
struct RequestLoginDTOTests {

    private func decode(_ json: String) -> RequestLoginDTO? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RequestLoginDTO.self, from: data)
    }

    @Test("유효한 JSON 디코딩")
    func decodesValidJSON() {
        let json = #"{"type":"sns-login","provider":"kakao"}"#
        let dto = decode(json)
        #expect(dto?.type == "sns-login")
        #expect(dto?.provider == .kakao)
    }

    @Test("모든 provider 디코딩")
    func decodesAllProviders() {
        let cases: [(String, RequestLoginDTO.Provider)] = [
            ("kakao", .kakao),
            ("naver", .naver),
            ("google", .google),
            ("apple", .apple)
        ]
        for (raw, expected) in cases {
            let json = #"{"type":"sns-login","provider":"\#(raw)"}"#
            let dto = decode(json)
            #expect(dto?.provider == expected)
        }
    }

    @Test("알 수 없는 provider는 디코딩 실패")
    func failsOnUnknownProvider() {
        let json = #"{"type":"sns-login","provider":"twitter"}"#
        #expect(decode(json) == nil)
    }

    @Test("필드 누락 시 디코딩 실패")
    func failsOnMissingFields() {
        #expect(decode(#"{"type":"sns-login"}"#) == nil)
        #expect(decode(#"{"provider":"kakao"}"#) == nil)
    }
}

// MARK: - SNSLoginSuccessPayload

@Suite("SNSLoginSuccessPayload")
struct SNSLoginSuccessPayloadTests {

    @Test("모든 필드 저장")
    func fieldsStored() {
        let payload = SNSLoginSuccessPayload(
            provider: "kakao",
            authorizeToken: "access_token_abc",
            refreshToken: "refresh_token_xyz",
            ci: "ci_value",
            email: "user@example.com"
        )
        #expect(payload.provider == "kakao")
        #expect(payload.authorizeToken == "access_token_abc")
        #expect(payload.refreshToken == "refresh_token_xyz")
        #expect(payload.ci == "ci_value")
        #expect(payload.email == "user@example.com")
    }

    @Test("email이 빈 값이면 jsonString에서 email 키 생략")
    func jsonStringOmitsBlankEmail() {
        let payload = SNSLoginSuccessPayload(
            provider: "google",
            authorizeToken: "token_123",
            refreshToken: "",
            ci: "",
            email: ""
        )
        let json = payload.jsonString ?? ""
        #expect(json.contains("\"provider\""))
        #expect(json.contains("\"google\""))
        #expect(json.contains("\"authorizeToken\""))
        #expect(json.contains("\"token_123\""))
        #expect(json.contains("\"refreshToken\""))
        #expect(json.contains("\"ci\""))
        // email은 값이 있을 때만 포함 — 빈 값이면 키 자체를 생략
        #expect(!json.contains("\"email\""))
    }

    @Test("공백만 있는 email은 nil 취급하여 키 생략")
    func jsonStringOmitsWhitespaceEmail() {
        let payload = SNSLoginSuccessPayload(
            provider: "kakao",
            authorizeToken: "token_123",
            refreshToken: "",
            ci: "",
            email: "   "
        )
        #expect(payload.email == nil)
        #expect(!(payload.jsonString ?? "").contains("\"email\""))
    }

    @Test("email이 있으면 jsonString에 email 키 포함")
    func jsonStringIncludesNonBlankEmail() {
        let payload = SNSLoginSuccessPayload(
            provider: "naver",
            authorizeToken: "token_123",
            refreshToken: "",
            ci: "",
            email: "user@example.com"
        )
        let json = payload.jsonString ?? ""
        #expect(json.contains("\"email\""))
        #expect(json.contains("user@example.com"))
    }

    @Test("유효한 JSON 생성")
    func producesValidJSON() throws {
        let payload = SNSLoginSuccessPayload(
            provider: "apple",
            authorizeToken: "id_token",
            refreshToken: "refresh",
            ci: "",
            email: "apple@icloud.com"
        )
        let json = try #require(payload.jsonString)
        let data = try #require(json.data(using: .utf8))
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(parsed?["provider"] == "apple")
        #expect(parsed?["authorizeToken"] == "id_token")
        #expect(parsed?["email"] == "apple@icloud.com")
    }
}

// MARK: - SNSLoginErrorPayload

@Suite("SNSLoginErrorPayload")
struct SNSLoginErrorPayloadTests {

    @Test("모든 필드 저장")
    func fieldsStored() {
        let payload = SNSLoginErrorPayload(
            code: "cancelled",
            message: "User cancelled",
            provider: "naver"
        )
        #expect(payload.code == "cancelled")
        #expect(payload.message == "User cancelled")
        #expect(payload.provider == "naver")
    }

    @Test("jsonString에 모든 필드 포함")
    func jsonStringContainsAllFields() {
        let payload = SNSLoginErrorPayload(
            code: "sdk_error",
            message: "Something went wrong",
            provider: "kakao"
        )
        let json = payload.jsonString ?? ""
        #expect(json.contains("\"code\""))
        #expect(json.contains("\"sdk_error\""))
        #expect(json.contains("\"message\""))
        #expect(json.contains("\"provider\""))
        #expect(json.contains("\"kakao\""))
    }

    @Test("유효한 JSON 생성")
    func producesValidJSON() throws {
        let payload = SNSLoginErrorPayload(
            code: "network_error",
            message: "No connection",
            provider: "google"
        )
        let json = try #require(payload.jsonString)
        let data = try #require(json.data(using: .utf8))
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(parsed?["code"] == "network_error")
        #expect(parsed?["message"] == "No connection")
        #expect(parsed?["provider"] == "google")
    }
}
