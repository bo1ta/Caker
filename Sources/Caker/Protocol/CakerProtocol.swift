//
//  CakerProtocol.swift
//  Caker
//
//  Created by Alexandru Solomon on 20.09.2025.
//

import Foundation

public protocol CakerProtocol {
  func getByKey<T: Codable & Sendable>(_ key: String, interval: TimeInterval, onRefresh: @escaping @Sendable () async throws -> T) async throws -> T
  func delete(key: String) async
}
