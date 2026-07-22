//
//  CertificationStatusResponseDTO.swift
//  ESTLoginKit
//
//  `GET {apiBaseURL}/members/v1/certification/status` 응답.
//

import Foundation

/// `{ "result": { "status": "..." }, "message": "" }`
struct CertificationStatusResponseDTO: Decodable {
  let result: Result

  struct Result: Decodable {
    let status: Status
  }

  /// "CERTIFIED"(완료) | "UNCERTIFIED"(미인증/미존재). 문서에 없는 값은 unknown으로 폴백.
  enum Status: String, Decodable {
    case certified = "CERTIFIED"
    case uncertified = "UNCERTIFIED"
    case unknown

    init(from decoder: Decoder) throws {
      let raw = try decoder.singleValueContainer().decode(String.self)
      self = Status(rawValue: raw) ?? .unknown
    }
  }
}
