# TanStack Query React - Complete Feature List

This document lists ALL features available in TanStack Query for React. SwiftUI Query aims to achieve feature parity with these capabilities, adapted for SwiftUI idioms.

## Core Query Hooks

### useQuery
Primary hook for fetching and caching data.
- [x] Query key management
- [x] Query function with context
- [x] Automatic refetching (mount, window focus, reconnect)
- [x] Background refetching with intervals
- [x] Stale time and garbage collection time configuration
- [x] Select transformation
- [x] Initial data and placeholder data
- [x] Structural sharing optimization
- [x] Network mode support (online/always/offlineFirst)
- [x] Retry logic with exponential/linear backoff
- [x] Error boundaries integration (throwOnError)
- [x] Promise-based API (experimental_prefetchInRender)
- [x] Subscription control
- [x] Query metadata

### useInfiniteQuery
Pagination with infinite scrolling support.
- [x] Page parameter management
- [x] getNextPageParam/getPreviousPageParam
- [x] fetchNextPage/fetchPreviousPage
- [x] hasNextPage/hasPreviousPage tracking
- [x] maxPages limitation
- [x] Bidirectional pagination
- [x] Page-specific error states

### useQueries
Dynamic parallel queries execution.
- [x] Array of query configurations
- [x] Combine function for aggregating results
- [x] Maintains order of results
- [x] Individual query state tracking

### useSuspenseQuery
Suspense-enabled queries (React 18+).
- [x] Guaranteed defined data
- [x] Simplified status states
- [x] React Suspense integration

### useSuspenseInfiniteQuery
Suspense-enabled infinite queries.
- [x] All useInfiniteQuery features with Suspense

### useSuspenseQueries
Suspense-enabled parallel queries.
- [x] All useQueries features with Suspense

## Mutation Hooks

### useMutation
Data modification operations.
- [x] Mutation function with variables
- [x] onMutate/onSuccess/onError/onSettled callbacks
- [x] Optimistic updates support
- [x] Mutation key for defaults inheritance
- [x] Retry configuration
- [x] Scope-based serial execution
- [x] Network mode support
- [x] mutate/mutateAsync methods
- [x] Reset functionality
- [x] Failure tracking
- [x] Submission timestamp

### useMutationState
Global mutation state access.
- [x] Filter mutations by key/status
- [x] Select specific mutation data
- [x] Access all mutation states

## Prefetching Hooks

### usePrefetchQuery
Render-time prefetching.
- [x] Prefetch during component render
- [x] Seamless integration with Suspense

### usePrefetchInfiniteQuery
Render-time infinite query prefetching.
- [x] Prefetch infinite queries during render

## State & Monitoring Hooks

### useIsFetching
Global fetching state indicator.
- [x] Count of fetching queries
- [x] Filter by query keys
- [x] App-wide loading indicators

### useIsMutating
Global mutation state indicator.
- [x] Count of pending mutations
- [x] Filter by mutation keys

### useQueryClient
Access QueryClient instance.
- [x] Direct cache manipulation
- [x] Custom QueryClient support

### useQueryErrorResetBoundary
Error boundary integration.
- [x] Reset query errors
- [x] Integration with React error boundaries

### useIsRestoring
Hydration state monitoring.
- [x] Check if cache restoration is in progress

## Configuration Functions

### queryOptions
Type-safe query configuration.
- [x] Reusable query configurations
- [x] TypeScript inference

### infiniteQueryOptions
Type-safe infinite query configuration.
- [x] Reusable infinite query configurations

### mutationOptions
Type-safe mutation configuration.
- [x] Reusable mutation configurations

## Provider Components

### QueryClientProvider
Root provider component.
- [x] QueryClient instance provision
- [x] Context-based client access

### QueryErrorResetBoundary
Error handling wrapper.
- [x] Error reset functionality
- [x] Render prop pattern

### HydrationBoundary
SSR hydration boundary.
- [x] Client-side hydration
- [x] Intelligent cache merging

### IsRestoringProvider
Restoration state provider.
- [x] Tracks cache restoration status

## Cache Management (QueryClient)

### Query Operations
- [x] fetchQuery/fetchInfiniteQuery
- [x] prefetchQuery/prefetchInfiniteQuery
- [x] getQueryData/ensureQueryData
- [x] setQueryData/setQueriesData
- [x] getQueryState
- [x] invalidateQueries
- [x] refetchQueries
- [x] cancelQueries
- [x] removeQueries
- [x] resetQueries

### Mutation Operations
- [x] isMutating
- [x] resumePausedMutations

### Configuration Methods
- [x] getDefaultOptions/setDefaultOptions
- [x] getQueryDefaults/setQueryDefaults
- [x] getMutationDefaults/setMutationDefaults

### Cache Access
- [x] getQueryCache/getMutationCache
- [x] clear

## DevTools

### ReactQueryDevtools
Floating developer tools.
- [x] Query/mutation visualization
- [x] Cache inspection
- [x] Manual query triggering
- [x] Error simulation
- [x] Network mode toggling
- [x] Customizable position
- [x] Shadow DOM support
- [x] CSP nonce support
- [x] Production lazy loading

### ReactQueryDevtoolsPanel
Embedded developer tools.
- [x] All DevTools features in embedded mode
- [x] Custom styling
- [x] Programmatic control

## Persistence & Hydration

### PersistQueryClientProvider
Persistent cache provider.
- [x] Automatic cache persistence
- [x] Restoration on mount
- [x] onSuccess/onError callbacks

### Hydration Functions
- [x] dehydrate - Serialize cache state
- [x] hydrate - Restore cache state
- [x] Configurable dehydration filters
- [x] Error redaction
- [x] Data serialization hooks

### Persistence Plugins
- [x] createSyncStoragePersister
- [x] createAsyncStoragePersister
- [x] Custom persister interface
- [x] Cache busting
- [x] Max age configuration
- [x] Throttled saves

## Advanced Features

### Network Modes
- [x] online - Default, pauses when offline
- [x] always - Ignores network state
- [x] offlineFirst - One attempt then pause

### Optimistic Updates
- [x] UI-based updates using variables
- [x] Cache-based updates with rollback
- [x] Context passing between callbacks

### Structural Sharing
- [x] Automatic reference preservation
- [x] Custom structural sharing functions
- [x] Performance optimization

### Query Filters
- [x] Filter by key/status/type
- [x] Exact/partial matching
- [x] Predicate functions

### Garbage Collection
- [x] Configurable GC time (gcTime)
- [x] Per-query GC settings
- [x] Infinite GC option

### Background Refetching
- [x] Interval-based refetching
- [x] Background tab support
- [x] Smart refetch conditions

### Query Cancellation
- [x] Automatic request cancellation
- [x] Manual cancellation
- [x] AbortController integration

### Default Query Function
- [x] Global query function
- [x] Per-query overrides

### Retry Strategies
- [x] Exponential backoff
- [x] Linear backoff
- [x] Custom retry logic
- [x] Max retry attempts

### Focus/Online Managers
- [x] Window focus detection
- [x] Network status monitoring
- [x] Custom event subscriptions

### Meta Information
- [x] Query/mutation metadata
- [x] Custom data attachment
- [x] Context propagation

## TypeScript Support
- [x] Full type inference
- [x] Generic type parameters
- [x] Type-safe query keys
- [x] Discriminated unions for states
- [x] Type guards for status checks

## React-Specific Features
- [x] Error boundary support
- [x] Suspense support
- [x] Server-side rendering (SSR)
- [x] Concurrent features compatibility
- [x] StrictMode compatibility
- [x] React DevTools integration

## SwiftUI Query Adaptation Notes

### Direct Mappings
- `useQuery` → `@Query` property wrapper
- `useMutation` → `@Mutation` property wrapper
- `useInfiniteQuery` → `@InfiniteQuery` property wrapper
- `QueryClientProvider` → Environment injection
- React hooks → Property wrappers or view modifiers

### SwiftUI-Specific Considerations
- Replace React Suspense with SwiftUI task/async patterns
- Use Swift actors instead of JavaScript closures for isolation
- Leverage Swift's type system for stronger guarantees
- Adapt to SwiftUI's view lifecycle
- Use Combine for reactive patterns where appropriate

### Feature Priority
1. **Phase 1**: Core query/mutation functionality
2. **Phase 2**: Infinite queries and parallel queries
3. **Phase 3**: Background refetching and lifecycle management
4. **Phase 4**: Persistence and hydration
5. **Phase 5**: DevTools and advanced features

This comprehensive list ensures SwiftUI Query can achieve complete feature parity with TanStack Query's React implementation.