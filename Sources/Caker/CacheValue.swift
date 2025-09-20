//
//  CacheValue.swift
//  Caker
//
//  Created by Alexandru Solomon on 20.09.2025.
//

import Foundation

internal struct CacheValue<T: Codable & Sendable>: Codable, AnyCacheValue {
  let value: T
  let expirationDate: Date
  
  func value<U>(as type: U.Type) throws -> U {
    guard let result = value as? U else {
      throw CakerError.invalidType
    }
    return result
  }
}
