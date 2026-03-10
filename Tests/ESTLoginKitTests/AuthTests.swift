import Foundation
import Testing
@testable import ESTLoginKit

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
