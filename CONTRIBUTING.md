# Contributing to SwiftGOAP

Thanks for thinking about contributing. SwiftGOAP is small, focused, and intentionally light on dependencies — that shape is worth preserving. Issues and pull requests are welcome for bug fixes, new features that fit the GOAP scope, and documentation improvements.

## Development setup

Requires Swift 5.7+ (Swift 6 recommended for strict-concurrency builds).

```bash
git clone https://github.com/ultrainfinity/SwiftGOAP.git
cd SwiftGOAP
swift build
swift test
```

## Running tests

```bash
swift test                                              # all 54 tests
swift test --filter PropertyBasedTests                  # 300 random problems
swift test --filter PerformanceTests                    # XCTMeasure baselines (macOS only)
swift build -Xswiftc -strict-concurrency=complete       # Swift 6 concurrency check
```

The CI runs the full matrix on every PR — `macOS-15` + `swift:6.0` Linux container, both in debug and release.

## Code style

- **Swift API Design Guidelines** — descriptive names, no abbreviations, clarity over brevity.
- **Zero runtime dependencies** — the only dev-time dependency is `apple/swift-docc-plugin`. New runtime dependencies need a strong justification.
- **`Sendable` everywhere** — all new public types should conform to `Sendable`. The package builds clean under `-strict-concurrency=complete` and should stay that way.
- **No Foundation imports** — the package is `import`-free for Linux portability. Use stdlib types only.
- **Doc comments on public API** — every public type, method, and property gets a `///` comment that explains intent, not mechanics. Include an example for non-obvious uses.
- **Tests for every behaviour change** — new conditions/effects/strategies should land with at least one unit test and, where relevant, a property-based check.

## Pull request process

1. Fork and create a feature branch from `main` (`feature/your-thing` or `fix/short-description`).
2. Make the change. Keep commits scoped — one logical change per commit.
3. Update `CHANGELOG.md` under `[Unreleased]`.
4. Make sure tests pass locally (`swift test`).
5. Open a PR with a clear summary of *what* changed and *why*. Link related issues.
6. Address review feedback by amending or adding commits (no force-push to a PR branch unless asked).

## Reporting bugs

Open an issue with:
- A minimal reproducible Swift snippet.
- Swift version (`swift --version`) and platform.
- Expected vs. actual behaviour.

## Suggesting features

Open a Discussion (preferred for design-shape questions) or an issue. Reference equivalent features in `stolk/GPGOAP`, `caesuric/mountain-goap`, or `kelindar/goap` when relevant — it makes the trade-off conversation faster.

## License

By contributing, you agree your contributions are licensed under the MIT License, same as the rest of the project.
