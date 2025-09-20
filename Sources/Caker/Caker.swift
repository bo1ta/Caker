
import Foundation
import os

public actor Caker: CakerProtocol {
  private enum CacheState {
    case inProgress(Task<Sendable, Error>)
    case completed(AnyCacheValue)
  }
  
  private var cacheStates: [String: CacheState] = [:]
  private var flushTask: Task<Void, Never>?
  
  private let logger = Logger(subsystem: "com.Caker", category: "Caker")
  private let userDefaults: UserDefaults?
  
  init(userDefaults: UserDefaults? = UserDefaults(suiteName: "com.Caker"), flushInterval seconds: TimeInterval = 600) {
    self.userDefaults = userDefaults
    
    Task {
      await createPeriodicFlushTask(flushInterval: seconds)
    }
  }
  
  deinit {
    flushTask?.cancel()
  }
  
  private func createPeriodicFlushTask(flushInterval: TimeInterval) {
    flushTask = Task { [weak self] in
      guard let self else { return }
      
      while true {
        do {
          try Task.checkCancellation()
          
          try await Task.sleep(for: .seconds(flushInterval))
          
          try Task.checkCancellation()
          
          await flushCache()
        } catch is CancellationError {
          break
        } catch {
          logger.error("Caker: Unexpected error in flush task: \(error)")
          break
        }
      }
    }
  }
  
  private func flushCache() async {
    let now = Date()
    let keysToRemove = cacheStates.compactMap { (key, state) -> String? in
      switch state {
      case .inProgress:
        return nil
      case .completed(let cacheValue):
        return cacheValue.expirationDate <= now ? key : nil
      }
    }
    
    for key in keysToRemove {
      await delete(key: key)
    }
  }
  
  public func getByKey<T: Codable & Sendable>(_ key: String, interval: TimeInterval, onRefresh: @escaping @Sendable () async throws -> T) async throws -> T {
    let cacheKey = cacheKey(key)
    
    if let cachedState = try await checkMemoryCache(cacheKey, withType: T.self) {
      return cachedState
    }
    
    if let cachedItem = checkPersistentCache(cacheKey, withType: T.self) {
      return cachedItem
    }
    
    let task = Task<Sendable, Error> {
      return try await onRefresh()
    }
    
    cacheStates[cacheKey] = .inProgress(task)
    
    guard let result = try await task.value as? T else {
      throw CakerError.invalidTask
    }
    
    storeCache(result, forKey: cacheKey, withInterval: interval)
    
    return result
  }
  
  public func delete(key: String) async {
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
      guard let result = try await task.value as? T else { throw CakerError.invalidTask }
      return result
      
    case .completed(let cacheValue):
      if cacheValue.expirationDate > Date() {
        return try cacheValue.value(as: type)
      }
    }
    
    return nil
  }
  
  private func checkPersistentCache<T: Codable & Sendable>(_ key: String, withType type: T.Type) -> T? {
    guard
      let cachedValue: CacheValue<T> = getCacheItem(forKey: key, withType: type),
      cachedValue.expirationDate > Date()
    else {
      return nil
    }
    
    cacheStates[key] = .completed(cachedValue)
    
    return cachedValue.value
  }
  
  private func cacheKey(_ key: String) -> String {
    "com.Caker.\(key)"
  }
  
  private func getCacheItem<T: Codable>(forKey key: String, withType type: T.Type) -> CacheValue<T>? {
    guard let cachedData = userDefaults?.data(forKey: key) else {
      return nil
    }
    
    do {
      return try JSONDecoder().decode(CacheValue<T>.self, from: cachedData)
    } catch {
      logger.error("Caker: Error decoding cached data: \(error)")
      return nil
    }
  }
  
  private func storeCache<T: Codable & Sendable>(_ data: T, forKey key: String, withInterval interval: TimeInterval) {
    let expirationDate = Date().addingTimeInterval(interval)
    cacheStates[key] = .completed(CacheValue(value: data, expirationDate: expirationDate))
    
    do {
      let cacheItem = CacheValue(value: data, expirationDate: expirationDate)
      let data = try JSONEncoder().encode(cacheItem)
      userDefaults?.set(data, forKey: key)
    } catch {
      logger.error("Caker: Error encoding data to cache: \(error)")
    }
  }
}
