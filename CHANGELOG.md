# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-01-08

### Added
- **Infinite Query Support** - Complete implementation of infinite queries with pagination
  - `UseInfiniteQuery` SwiftUI component for infinite scrolling
  - `InfiniteQuery` core class for managing paginated data
  - `InfiniteQueryObserver` for reactive infinite query state management
  - Support for bidirectional pagination (next/previous pages)
  - Automatic page parameter calculation
  - Built-in pull-to-refresh support
- **Configurable Initial Page** - Pokemon demo now supports starting from any offset
  - UI controls for selecting initial page
  - Automatic refresh when initial page changes
  - Proper cache separation for different starting points
- **Enhanced SwiftUI Integration**
  - Fixed actor isolation issues for Swift 6 strict concurrency
  - Improved `onChange` handlers in `UseInfiniteQuery`
  - Better error handling and loading states

### Changed
- **Type Constraints** - Added `Equatable` constraint to `TPageParam` for proper change detection
- **Options Handling** - Fixed issue where old options were used instead of current options
- **Demo App** - Updated Pokemon list to showcase infinite query capabilities

### Fixed
- **Pull-to-Refresh Bug** - Fixed issue where first page was appended instead of resetting
- **Actor Isolation** - Resolved Swift concurrency errors with `@State` properties in closures
- **Query Key Changes** - Fixed `UseInfiniteQuery` to properly handle query key updates

### Technical
- Swift 6.0 compatible with strict concurrency mode
- Comprehensive unit tests for infinite query functionality
- Updated to use Perception library for iOS 16+ compatibility
- Enhanced logging and debugging capabilities

## [0.1.0] - 2024-12-XX

### Added
- Initial release of SwiftUI Query
- **Core Query System**
  - `UseQuery` SwiftUI component for data fetching
  - `Query` class for individual query management
  - `QueryClient` for centralized query management
  - `QueryCache` with thread-safe operations
- **SwiftUI Integration**
  - `QueryClientProvider` for dependency injection
  - Environment-based query client access
  - Reactive state updates with `@Perceptible`
- **Advanced Features**
  - Automatic refetching (on mount, focus, reconnect)
  - Request deduplication and caching
  - Configurable retry logic with exponential backoff
  - Garbage collection for unused queries
  - Stale-while-revalidate caching strategy
- **Developer Experience**
  - Comprehensive unit test suite
  - Swift 6 strict concurrency compliance
  - Multi-platform support (iOS, macOS, tvOS, watchOS)
  - Complete Pokemon API demo application

[Unreleased]: https://github.com/muzix/SwiftUIQuery/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/muzix/SwiftUIQuery/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/muzix/SwiftUIQuery/releases/tag/v0.1.0