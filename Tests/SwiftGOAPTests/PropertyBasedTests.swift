import XCTest
@testable import SwiftGOAP

/// Property-based tests. Generates random GOAP problems with a seeded RNG and
/// checks invariants of the returned plans:
///   1. Every action's preconditions hold in the state it was scheduled for.
///   2. The final state satisfies the goal.
///   3. The trajectory in `plan.states` matches the action-by-action replay.
///   4. `plan.totalCost` equals the sum of `cost(in:)` evaluated along the
///      trajectory.
///
/// Seed is fixed so failures are reproducible. Bump the iteration count when
/// debugging to widen coverage.
final class PropertyBasedTests: XCTestCase {

    /// Deterministic splitmix64 RNG, so CI failures can be reproduced locally.
    struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    func testRandomBooleanProblemsProducedValidPlans() {
        var rng = SplitMix64(state: 0xC0FFEE_BEEF_F00D)
        let numFacts = 8
        let iterations = 300

        var plannedCount = 0
        var nilCount = 0

        for iteration in 0..<iterations {
            // Build a random action set.
            let numActions = Int.random(in: 2...8, using: &rng)
            var actions: [BasicAction<BooleanWorldState>] = []
            for i in 0..<numActions {
                actions.append(BasicAction(
                    name: "a\(iteration)_\(i)",
                    cost: Int.random(in: 1...4, using: &rng),
                    preconditions: randomPartialState(numFacts: numFacts, maxBits: 3, rng: &rng),
                    effects: randomPartialState(numFacts: numFacts, maxBits: 3, rng: &rng)
                ))
            }

            // Build a random start state — fully defined so satisfies semantics
            // are unambiguous.
            var start = BooleanWorldState()
            for f in 0..<numFacts {
                start.set(f, to: Bool.random(using: &rng))
            }

            // Build a random goal.
            let goal = randomPartialState(numFacts: numFacts, maxBits: 2, rng: &rng)

            let planner = GOAPPlanner<BooleanWorldState>(maxNodes: 5_000)
            guard let plan = planner.plan(from: start, goal: goal, actions: actions) else {
                nilCount += 1
                continue
            }
            plannedCount += 1

            // Invariants -------------------------------------------------------

            // 1. Trajectory length.
            XCTAssertEqual(
                plan.states.count, plan.actions.count + 1,
                "iteration \(iteration): trajectory length mismatch"
            )
            // 2. First state is start; last state satisfies goal.
            XCTAssertEqual(plan.states.first, start, "iteration \(iteration): plan must start at start")
            XCTAssertTrue(
                plan.states.last!.satisfies(goal),
                "iteration \(iteration): final state must satisfy goal"
            )
            // 3. Each step: preconditions hold + effects produce next state.
            var replayedCost = 0
            for i in 0..<plan.actions.count {
                let s = plan.states[i]
                let a = plan.actions[i]
                XCTAssertTrue(
                    s.satisfies(a.preconditions),
                    "iteration \(iteration): action \(a.name) at step \(i) failed precondition check"
                )
                XCTAssertEqual(
                    plan.states[i + 1], s.applying(a.effects),
                    "iteration \(iteration): trajectory diverges at step \(i)"
                )
                replayedCost += a.cost(in: s)
            }
            // 4. totalCost matches replayed cost.
            XCTAssertEqual(plan.totalCost, replayedCost, "iteration \(iteration): totalCost mismatch")
        }

        // Smoke check: we should have planned some non-trivial fraction of the
        // problems. If everything returned nil, the generator is broken.
        XCTAssertGreaterThan(
            plannedCount, iterations / 5,
            "too few problems planned (\(plannedCount)/\(iterations)) — generator may be too constrained"
        )
        XCTAssertGreaterThan(
            nilCount, 0,
            "no problems returned nil — generator may be too easy and not exercising the no-plan path"
        )
    }

    /// Builds a partial `BooleanWorldState` with up to `maxBits` random
    /// (fact, value) pairs. Useful for preconditions, effects, and goals.
    private func randomPartialState(
        numFacts: Int,
        maxBits: Int,
        rng: inout SplitMix64
    ) -> BooleanWorldState {
        let n = Int.random(in: 0...maxBits, using: &rng)
        var s = BooleanWorldState()
        for _ in 0..<n {
            let bit = Int.random(in: 0..<numFacts, using: &rng)
            s.set(bit, to: Bool.random(using: &rng))
        }
        return s
    }
}
