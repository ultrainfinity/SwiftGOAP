# Changelog

All notable changes to **SwiftGOAP** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Until 1.0, minor versions may contain breaking changes.

## [Unreleased]

## [0.1.0] — 2026-05-14

First public release. The first open-source GOAP (Goal-Oriented Action Planning) library for Swift.

### Added

- `WorldState` protocol with `Conditions` / `Effects` associated types, both `Sendable`.
- `BooleanWorldState` — bitmask-backed state with up to 64 boolean facts. O(1) `satisfies` / `applying` / heuristic. Enforces the invariant `bits & ~mask == 0` on construction.
- `RichWorldState` — `[String: StateValue]` with `bool`/`integer`/`real`/`text` values. Supports numeric comparison conditions (`>=`, `<`, …) and additive effects (`set`, `add`, `subtract`). `.add` / `.subtract` trap on missing or non-numeric facts.
- `GOAPAction` protocol + `BasicAction<State>` concrete type. Optional `cost(in: State) -> Int` override for dynamic, state-modulated costs (default returns the static `cost`).
- `GOAPGoal<State>` with `name`, `conditions`, and `priority`.
- `GOAPPlan<Action>` value type carrying the action sequence, the full trajectory of intermediate states, and a computed `totalCost`.
- `GOAPPlanner<State>` running A\* with a closed-set + reopen-on-better-g optimisation and a configurable `maxNodes` cap.
- Single-goal `plan(from:goal:actions:)` plus a dynamic-action overload `plan(from:goal:actionsFor:)` that generates the action set per-state.
- Multi-goal `plan(from:goals:actions:selectingBy:)` with two strategies: `.priority` (first achievable) and `.maxUtility` (maximise `priority - totalCost`).
- `PriorityQueue<Element>` binary min-heap (conditionally `Sendable`).
- Type-safe fact overloads: any `RawRepresentable` whose `RawValue` is `Int` works with `BooleanWorldState.facts/set/get/clear`.
- `Sendable` conformance on every public type — builds clean under `-strict-concurrency=complete`.
- DocC catalog (`Sources/SwiftGOAP/SwiftGOAP.docc`) with module overview and Topics groupings.
- 54-test suite, including property-based fuzz tests (300 random problems, deterministic SplitMix64 seed) and XCTMeasure performance baselines.
- GitHub Actions CI matrix: macOS 15 + Linux (swift:6.0) with debug, release, and strict-concurrency builds.

### Notes

- Pure Swift, zero runtime dependencies. The only dev-time dependency is `apple/swift-docc-plugin` for documentation generation.
- The default planning heuristic is "count of unsatisfied facts". This is fast but not strictly admissible when one action can satisfy several conditions at once, so A\* may occasionally return a plan one step longer than optimal — the standard GOAP trade-off.

[Unreleased]: https://github.com/ultrainfinity/SwiftGOAP/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ultrainfinity/SwiftGOAP/releases/tag/v0.1.0
