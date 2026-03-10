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
