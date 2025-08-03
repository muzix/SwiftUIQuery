# SwiftUI Query Development Guide

This project is a Swift implementation of TanStack Query for SwiftUI applications. This guide helps maintain consistency and quality throughout development.

## Documentation Structure

- [principles.md](./principles.md) - Core principles, philosophy, and Swift 6 compliance
- [api-design.md](./api-design.md) - API patterns, usage examples
- [roadmap.md](./roadmap.md) - Development roadmap with phases and milestones
- [feature-parity.md](./feature-parity.md) - Complete list of TanStack Query React features to implement
- architecture.md - Technical architecture and component design (planned)
- optimization.md - Performance and memory optimization guidelines (planned)
- networking.md - Network abstraction layer details (planned)

## TanStack Query Reference

The `Documentation` folder contains the complete TanStack Query source code. When implementing ANY feature, you MUST reference the original implementation to ensure architectural consistency.

### Core Implementation Files (MUST READ)

#### Query Core (`Documentation/query/packages/query-core/src/`)
- `queryClient.ts` - Central client managing all queries/mutations
- `queryCache.ts` - Query state cache implementation
- `mutationCache.ts` - Mutation state cache implementation
- `query.ts` - Individual query instance logic
- `mutation.ts` - Individual mutation instance logic
- `queryObserver.ts` - Observer pattern for reactive updates
- `infiniteQueryObserver.ts` - Infinite query implementation
- `retryer.ts` - Retry logic with exponential backoff
- `focusManager.ts` - Window focus detection
- `onlineManager.ts` - Online/offline detection
- `notifyManager.ts` - Notification scheduling
- `types.ts` - Core TypeScript types

#### React Implementation (`Documentation/query/packages/react-query/src/`)
- `useQuery.ts` - Query hook implementation
- `useMutation.ts` - Mutation hook implementation
- `useInfiniteQuery.ts` - Infinite query hook
- `useBaseQuery.ts` - Shared query logic
- `QueryClientProvider.tsx` - React context pattern

### Implementation Guidelines

1. **ALWAYS check TanStack Query implementation first**
   - Before implementing any feature, find the corresponding code in Documentation folder
   - Study both query-core (logic) and react-query (integration) implementations
   - Adapt TypeScript patterns to Swift idioms

2. **Follow TanStack Query's Architecture**
   - Observer pattern for reactive updates
   - Separate caches for queries and mutations
   - Framework-agnostic core with thin framework wrapper
   - Stale-while-revalidate caching strategy

3. **Maintain Feature Parity**
   - Default behaviors (see `Documentation/query/docs/framework/react/guides/important-defaults.md`)
   - Automatic refetching (mount, focus, reconnect)
   - Query invalidation and garbage collection
   - Structural sharing for performance

### Key Requirements
- Swift 6 strict concurrency mode compatible
- Built with Swift Observation framework (@Observable)
- Zero external dependencies
- Match TanStack Query's architecture and behavior

### Development Checklist
- [ ] Referenced corresponding TanStack Query implementation
- [ ] All types are Sendable
- [ ] Using @Observable instead of ObservableObject
- [ ] Matches TanStack Query behavior
- [ ] Full DocC documentation
- [ ] Unit tests for all public APIs

## Getting Started

1. Study TanStack Query source in `Documentation/query/packages/`
2. Review [principles.md](./principles.md) for Swift-specific adaptations
3. Follow [api-design.md](./api-design.md) for SwiftUI integration patterns
4. Always reference original TypeScript implementation
5. Adapt patterns to Swift 6 concurrency model

## Testing Commands

When implementing features, run these commands:
```bash
swift test
swift build -Xswiftc -strict-concurrency=complete
```

**IMPORTANT TESTING RULES:**
- **Only run `swift test` when you have made changes to test code**
- If you're implementing features without updating tests, do NOT run `swift test`
- Use `swift build` to verify compilation after implementation changes
- Never run `xcodebuild` commands on .xcodeproj files
- The Example/ directory contains Xcode projects for manual testing only
- Only use swift test and swift build commands for automated verification

## Important TanStack Query Defaults to Implement

From the official documentation:
- Query results are cached and considered stale immediately
- Stale queries refetch automatically on:
  - New instances mount
  - Window refocus
  - Network reconnect
  - Optional: at configured intervals
- Inactive queries garbage collected after 5 minutes
- Failed queries retry 3 times with exponential backoff
- Query results are structurally shared to detect changes

## Documentation Review Tasks

- Read documents in @Documentation/query/docs/framework/react/

## Development Best Practices

- When implementing swift version of react query, always looks for latest implementation details from react query. Behavior of enum, public API should be kept closest as much as possible

## Development Workflow

- Remember to add/update unit tests after each task
- After each task, run make format and make lint / make lint-fix and fix issues if needed. Then commit code.