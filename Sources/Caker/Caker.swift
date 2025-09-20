import Foundation
import os

public protocol CakerProtocol {
  func getByKey<T: Codable & Sendable>(_ key: String, interval: TimeInterval, onRefresh: @escaping @Sendable () async -> T) async throws -> T
  func delete(key: String) async
}

public actor Caker: CakerProtocol {
  private let userDefaults = UserDefaults(suiteName: "com.Caker")
  private let logger = Logger(subsystem: "com.Caker", category: "Caker")
  
  private var cacheStates: [String: CacheState] = [:]
    
  public func getByKey<T: Codable & Sendable>(_ key: String, interval: TimeInterval, onRefresh: @escaping @Sendable () async -> T) async throws -> T {
    let cacheKey = cacheKey(key)
    
    if let cachedState = try await checkMemoryCache(cacheKey, withType: T.self) {
      return cachedState
    }
    
    if let cachedItem = checkPersistentCache(cacheKey, withType: T.self) {
      return cachedItem
    }
    
    let task = Task<Sendable, Never> {
      return await onRefresh()
    }
    
    cacheStates[cacheKey] = .inProgress(task)
    
    guard let result = await task.value as? T else {
      throw CakerError.invalidTask
    }
    
    storeCache(result, forKey: cacheKey, withInterval: interval)
    
    return result
  }
  
  public func delete(key: String) {
    let cacheKey = cacheKey(key)
    cacheStates.removeValue(forKey: cacheKey)
    userDefaults?.removeObject(forKey: cacheKey)
  }
  
  private func checkMemoryCache<T: Codable & Sendable>(_ key: String, withType type: T.Type) async throws -> T? {
    guard let cachedState = cacheStates[key] else {
      return nil
    }
    
    switch cachedState {
    case .inProgress(let task):
      guard let result = await task.value as? T else { throw CakerError.invalidTask }
      return result
      
    case .completed(let expiration, let value):
      if expiration > Date(), let typedValue = value as? T {
        return typedValue
      }
    }
    
    return nil
  }
  
  private func checkPersistentCache<T: Codable & Sendable>(_ key: String, withType type: T.Type) -> T? {
    guard
      let cachedItem: CacheItem<T> = getCacheItem(forKey: key, withType: type),
      cachedItem.expirationDate > Date()
    else {
      return nil
    }
    
    cacheStates[key] = .completed(expiration: cachedItem.expirationDate, value: cachedItem.value)
    
    return cachedItem.value
  }
  
  private func cacheKey(_ key: String) -> String {
    "com.Caker.\(key)"
  }
  
  private func getCacheItem<T: Codable>(forKey key: String, withType type: T.Type) -> CacheItem<T>? {
    guard let cachedData = userDefaults?.data(forKey: key) else {
      return nil
    }
    
    do {
      return try JSONDecoder().decode(CacheItem<T>.self, from: cachedData)
    } catch {
      logger.error("Caker: Error decoding cached data: \(error)")
      return nil
    }
  }
  
  private func storeCache<T: Codable & Sendable>(_ data: T, forKey key: String, withInterval interval: TimeInterval) {
    let expirationDate = Date().addingTimeInterval(interval)
    cacheStates[key] = .completed(expiration: expirationDate, value: data)

    do {
      let cacheItem = CacheItem(value: data, expirationDate: expirationDate)
      let data = try JSONEncoder().encode(cacheItem)
      userDefaults?.set(data, forKey: key)
    } catch {
      logger.error("Caker: Error encoding data to cache: \(error)")
    }
  }
}

// MARK: - Helpers

extension Caker {
  private enum CacheState {
    case inProgress(Task<Sendable, Never>)
    case completed(expiration: Date, value: Sendable)
  }
  
  private struct CacheItem<T: Codable>: Codable {
    let value: T
    let expirationDate: Date
  }
  
  public enum CakerError: Error {
    case invalidTask
  }
}
