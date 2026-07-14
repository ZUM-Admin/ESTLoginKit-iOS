import Foundation
import Testing
@testable import ESTLoginKit

// MARK: - 완료 통지 → Result 매핑

@Suite("본인인증 완료 통지 매핑")
struct VerificationResultMappingTests {

    @Test("certified + token → success")
    func certifiedWithTokenSucceeds() throws {
        let result = VerificationCompleteStatus.result(status: "certified", token: "sso_abc")
        #expect(try result.get().token == "sso_abc")
    }

    @Test("certified인데 token 없음 → verificationFailed (세션 재수립 불가)")
    func certifiedWithoutTokenFails() {
        let result = VerificationCompleteStatus.result(status: "certified", token: nil)
        #expect(throws: AuthError.self) { try result.get() }
    }

    @Test("cancelled → cancelled")
    func cancelledMapsToCancelled() {
        let result = VerificationCompleteStatus.result(status: "cancelled", token: nil)
        guard case .failure(let error) = result, case .cancelled = error else {
            Issue.record("AuthError.cancelled여야 합니다")
            return
        }
    }

    @Test("error → verificationFailed")
    func errorMapsToVerificationFailed() {
        let result = VerificationCompleteStatus.result(status: "error", token: nil)
        guard case .failure(let error) = result, case .verificationFailed = error else {
            Issue.record("AuthError.verificationFailed여야 합니다")
            return
        }
    }

    @Test("알 수 없는 status → verificationFailed")
    func unknownStatusMapsToVerificationFailed() {
        let result = VerificationCompleteStatus.result(status: "weird", token: "sso_abc")
        guard case .failure(let error) = result, case .verificationFailed = error else {
            Issue.record("AuthError.verificationFailed여야 합니다")
            return
        }
    }

    @Test("status 없음(파싱 실패) → verificationFailed")
    func missingStatusMapsToVerificationFailed() {
        let result = VerificationCompleteStatus.result(status: nil, token: nil)
        guard case .failure(let error) = result, case .verificationFailed = error else {
            Issue.record("AuthError.verificationFailed여야 합니다")
            return
        }
    }
}

// MARK: - 브릿지 페이로드 디코딩

@Suite("VerificationCompletePayload 디코딩")
struct VerificationCompletePayloadTests {

    private func decode(_ json: String) throws -> VerificationCompletePayload {
        try JSONDecoder.instance.decode(VerificationCompletePayload.self, from: Data(json.utf8))
    }

    @Test("certified 페이로드")
    func decodesCertified() throws {
        let dto = try decode(#"{"status":"certified","token":"sso_abc"}"#)
        #expect(dto.status == "certified")
        #expect(dto.token == "sso_abc")
    }

    @Test("token 없는 cancelled 페이로드")
    func decodesCancelledWithoutToken() throws {
        let dto = try decode(#"{"status":"cancelled"}"#)
        #expect(dto.status == "cancelled")
        #expect(dto.token == nil)
    }

    @Test("문서에 없는 status도 디코딩은 성공 (해석은 매핑 단계에서)")
    func decodesUnknownStatus() throws {
        let dto = try decode(#"{"status":"whatever"}"#)
        #expect(dto.status == "whatever")
    }
}

// MARK: - 본인인증 화면 URL

@Suite("verificationURL")
struct VerificationURLTests {

    init() {
        // verificationURL은 clientId가 필수 — initialize된 상태를 재현
        ESTLoginManager.configuration = ESTLoginConfiguration.Builder(clientId: "test_client").build()
    }

    @Test("client_id는 항상 쿼리에 포함")
    func urlWithoutCallback() {
        let url = ESTLoginManager.shared.verificationURL()
        #expect(url.path == "/webview/verification")
        #expect(url.queryValue(for: "client_id") == "test_client")
        #expect(url.queryValue(for: "callbackURL") == nil)
    }

    @Test("callbackURL은 인코딩되어 쿼리로 붙는다")
    func urlWithCallbackIsEncoded() {
        let callback = "https://app.example.com/cb?a=1&b=2"
        let url = ESTLoginManager.shared.verificationURL(callbackURL: callback)
        // 인코딩이 깨지면 callbackURL의 &b=2가 최상위 쿼리로 새어나온다.
        #expect(url.queryValue(for: "client_id") == "test_client")
        #expect(url.queryValue(for: "callbackURL") == callback)
        #expect(url.queryValue(for: "b") == nil)
    }
}
