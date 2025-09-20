import Testing
import Foundation
@testable import Caker

@Suite("Caker")
struct CakerTests {
  @Test func firstCacheCallsRefresh() async throws {
    let testKey = "basic_test"
    let expectedValue = "test_value"
    
    let caker = Caker(userDefaults: UserDefaults(suiteName: #file))
    let result = try await confirmation(expectedCount: 1) { confirm in
      try await caker.getByKey(testKey, interval: 3600) {
        confirm(count: 1)
        return expectedValue
      }
    }
    
    #expect(result == expectedValue)
  }
  
  @Test func refreshIsCalledOnce() async throws {
    let testKey = "basic_test"
    let expectedValue = "test_value"
    
    let result = try await confirmation(expectedCount: 1) { confirm in
      let caker = Caker(userDefaults: UserDefaults(suiteName: #function))
      
      _ = try await caker.getByKey(testKey, interval: 3600) {
        confirm(count: 1)
        return expectedValue
      }
      
      _ = try await caker.getByKey(testKey, interval: 3600) {
        confirm(count: 2)
        return "Should not be called"
      }
      
      return try await caker.getByKey(testKey, interval: 3600) {
        confirm(count: 3)
        return "Should not be called"
      }
    }
    
    #expect(result == expectedValue)
  }
  
  @Test func cacheExpiresCorrectly() async throws {
    let testKey = "expiration_test"
    let userDefaults = UserDefaults(suiteName: #function)
    
    let caker = Caker(userDefaults: userDefaults)
    
    let result1 = try await confirmation(expectedCount: 1) { confirm in
      try await caker.getByKey(testKey, interval: 0.1) {
        confirm(count: 1)
        return "first_value"
      }
    }
    
    #expect(result1 == "first_value")
    
    try await Task.sleep(nanoseconds: 300_000_000)
    
    let result2 = try await confirmation(expectedCount: 2) { confirm in
      try await caker.getByKey(testKey, interval: 0.1) {
        confirm(count: 2)
        return "second_value"
      }
    }
    #expect(result2 == "second_value")
  }
  
}
