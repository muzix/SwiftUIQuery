# ``SwiftUIQuery``

A Swift implementation of TanStack Query for SwiftUI applications.

## Overview

SwiftUI Query brings the power of TanStack Query to SwiftUI, providing declarative data fetching with automatic caching, synchronization, and background updates. Built with Swift 6 strict concurrency compliance and zero external dependencies.

### Key Features

- **Declarative data fetching** with SwiftUI property wrappers
- **Automatic caching** with stale-while-revalidate strategy
- **Background refetching** on app focus, network reconnection, and mount
- **Optimistic updates** for smooth user experiences
- **Request deduplication** to prevent duplicate network calls
- **Offline support** with automatic retries
- **Swift 6 compliant** with strict concurrency checking

## Topics

### Getting Started
- <doc:Installation>
- <doc:QuickStart>
- <doc:BasicUsage>

### Core Concepts
- <doc:Queries>
- <doc:Mutations>
- <doc:QueryClient>
- <doc:Caching>

### Advanced Features
- <doc:InfiniteQueries>
- <doc:OptimisticUpdates>
- <doc:QueryInvalidation>
- <doc:OfflineSupport>

### Property Wrappers
- ``Query``
- ``Mutation``
- ``InfiniteQuery``

### Core Classes
- ``QueryClient``
- ``QueryCache``
- ``MutationCache``

### Migration and Compatibility
- <doc:MigrationGuide>
- <doc:TanStackComparison>

## See Also
- [TanStack Query Documentation](https://tanstack.com/query)
- [SwiftUI Query GitHub Repository](https://github.com/muzix/swiftui-query)