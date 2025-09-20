## Caker

A lightweight, thread-safe caching system for Swift with memory and persistent storage support.

## Features

- Thread-safe: Built on Swift actors for safe concurrent access
- Dual-layer caching: In-memory for speed + UserDefaults for persistence
- Automatic expiration: Configurable time-to-live for cached items
- Refresh prevention: Prevents duplicate refresh operations for the same key
- Memory management: Periodic cleanup of expired entries

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bo1ta/Caker.git", from: "0.9.0")
]

```

Or add directly in Xcode via File > Add Packages.

## Usage

### Basic Setup

```swift

import Caker

// Create a shared instance (recommended)
let caker = Caker()

// Or customize with your own UserDefaults suite
let customCaker = Caker(userDefaults: UserDefaults(suiteName: "com.yourapp.cache"))
```

### Caching Data

```swift
let userProfile = try await caker.getByKey(
    "userProfile", 
    interval: 3600, // 1 hour expiration
    onRefresh: {
        return try await fetchUserProfileFromAPI()
    }
)
```

### Managing Cache

- The periodic flush task automatically removes expired entries
- You can also manually trigger cleanup if needed

```swift
// Remove specific item
await caker.delete(key: "userProfile")
```

#### Custom Flush Intervals

- Clean up expired entries every 5 minutes instead of default 10
```swift
let frequentFlusher = Caker(seconds: 300)
```

### Error handling

Caker throws errors for:
	- Failed refresh operations
	- Type casting issues
	- Task cancellation
	
### Performance Notes

- In-memory cache is checked first for fastest access
- UserDefaults persistence ensures data survives app restarts
- The flush task runs every 10 minutes by default to free memory

### License

MIT License - see LICENSE file for details

### Contributing

Pull requests and issues are welcome. Please ensure tests pass and follow the existing code style.