import SwiftGOAP

/// Bench: single-operation throughput for BooleanWorldState vs RichWorldState.
///
/// Each pair (Boolean: X, Rich: X) measures the same logical operation against
/// the same logical world. Numbers are best-of-N samples per op.
///
/// The work in each closure has to be observable — otherwise the optimiser
/// folds it away. `Blackhole.observe(_:)` writes through a memory barrier so
/// the result can't be dead-code-eliminated.
func runPrimitiveBenchmarks(into runner: inout BenchmarkRunner) {

    // Two worlds with semantically identical content: 4 boolean facts set,
    // one fully populated, one for use as a condition / effect.
    let boolFull = BooleanWorldState.facts([
        (0, true), (1, true), (2, false), (3, true)
    ])
    let boolCondition = BooleanWorldState.facts([
        (0, true), (3, true)
    ])
    let boolEffects = BooleanWorldState.facts([
        (1, false), (2, true)
    ])

    let richFull = RichWorldState([
        "f0": .bool(true),
        "f1": .bool(true),
        "f2": .bool(false),
        "f3": .bool(true)
    ])
    let richCondition: [String: StateCondition] = [
        "f0": .equals(.bool(true)),
        "f3": .equals(.bool(true))
    ]
    let richEffects: [String: StateEffect] = [
        "f1": .set(.bool(false)),
        "f2": .set(.bool(true))
    ]

    // satisfies — does the world satisfy a 2-fact condition?
    runner.measure("Boolean: satisfies (2 facts)", category: "Primitive ops") {
        Blackhole.observe(boolFull.satisfies(boolCondition))
    }
    runner.measure("Rich: satisfies (2 facts)", category: "Primitive ops") {
        Blackhole.observe(richFull.satisfies(richCondition))
    }

    // applying — produce a new state with 2 effects applied.
    runner.measure("Boolean: applying (2 effects)", category: "Primitive ops") {
        Blackhole.observe(boolFull.applying(boolEffects))
    }
    runner.measure("Rich: applying (2 effects)", category: "Primitive ops") {
        Blackhole.observe(richFull.applying(richEffects))
    }

    // heuristicDistance — count of unsatisfied facts.
    let boolGoal = BooleanWorldState.facts([
        (0, false), (1, false), (2, true), (3, false)
    ])
    let richGoal: [String: StateCondition] = [
        "f0": .equals(.bool(false)),
        "f1": .equals(.bool(false)),
        "f2": .equals(.bool(true)),
        "f3": .equals(.bool(false))
    ]
    runner.measure("Boolean: heuristicDistance (4 conds)", category: "Primitive ops") {
        Blackhole.observe(boolFull.heuristicDistance(to: boolGoal))
    }
    runner.measure("Rich: heuristicDistance (4 conds)", category: "Primitive ops") {
        Blackhole.observe(richFull.heuristicDistance(to: richGoal))
    }

    // Set insert — this is the dominant cost inside A*'s closed-set and
    // gScore dictionary. We make sure to measure a *fresh* state each time
    // so we hit hashing and equality work, not cache.
    var i = 0
    runner.measure("Boolean: hash + Set insert", category: "Set membership") {
        var s = boolFull
        s.set(0, to: (i & 1) == 0)
        Blackhole.observe(Set([s]).count)
        i &+= 1
    }
    var j = 0
    runner.measure("Rich: hash + Set insert", category: "Set membership") {
        var values = richFull.values
        values["f0"] = .bool((j & 1) == 0)
        let s = RichWorldState(values)
        Blackhole.observe(Set([s]).count)
        j &+= 1
    }
}

/// Prevents the optimiser from eliminating "useless" computation that the
/// benchmark depends on. `@inline(never)` blocks the call from being folded;
/// writing to a static `Any` global forces the value to be materialised.
enum Blackhole {
    @inline(never)
    static func observe<T>(_ value: T) {
        _anchor = value
    }
    nonisolated(unsafe) static var _anchor: Any = 0
}
