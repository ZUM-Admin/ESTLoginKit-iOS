//
//  AuthProvider.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import Foundation

/// 다양한 로그인 구현체들이 따를 프로토콜
public protocol AuthProvider {
    /// 실제 로그인 수행
    /// - Returns: 성공 시 토큰 문자열 (또는 커스텀 모델)
    func login() async throws -> String
}
