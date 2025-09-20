//
//  AnyCacheValue.swift
//  Caker
//
//  Created by Alexandru Solomon on 20.09.2025.
//

import Foundation

internal protocol AnyCacheValue: Sendable {
  var expirationDate: Date { get }
  
  func value<T>(as type: T.Type) throws -> T
}
