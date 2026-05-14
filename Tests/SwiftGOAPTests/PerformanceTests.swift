import XCTest
@testable import SwiftGOAP

/// Performance smoke tests. These don't fail on slow runs — they're here to
/// document expected order-of-magnitude latency and to catch large
/// regressions when reviewing diffs. Output appears in `swift test`'s
/// performance summary on Apple platforms.
final class PerformanceTests: XCTestCase {

    /// A medium-depth boolean plan: 12 facts, ~12 chained actions producing a
    /// 10-step plan. Representative of a typical game-AI problem.
    func testMediumBooleanPlan() {
        let numFacts = 12
        // Chain: each action requires fact i true and produces fact i+1 true.
        var actions: [BasicAction<BooleanWorldState>] = []
        for i in 0..<(numFacts - 1) {
            actions.append(BasicAction(
                name: "step\(i)",
                preconditions: BooleanWorldState.facts([(i, true)]),
                effects: BooleanWorldState.facts([(i + 1, true)])
            ))
        }
        // Add a few distractor actions to give A* something to discard.
        for i in 0..<6 {
            actions.append(BasicAction(
                name: "distract\(i)",
                cost: 10,
                preconditions: BooleanWorldState(),
                effects: BooleanWorldState.facts([(numFacts + i, true)])
            ))
        }

        let start = BooleanWorldState.facts([(0, true)])
        let goal = BooleanWorldState.facts([(numFacts - 1, true)])
        let planner = GOAPPlanner<BooleanWorldState>()

        measure {
            for _ in 0..<100 {
                _ = planner.plan(from: start, goal: goal, actions: actions)
            }
        }
    }

    /// A shallow plan with many candidate actions — exercises the branching
    /// factor side of A* rather than depth.
    func testWideShallowBooleanPlan() {
        // 30 actions, all applicable from the start state, only one reaches the goal.
        var actions: [BasicAction<BooleanWorldState>] = []
        for i in 0..<30 {
            actions.append(BasicAction(
                name: "a\(i)",
                cost: i == 7 ? 1 : 100,
                preconditions: BooleanWorldState(),
                effects: BooleanWorldState.facts([(i % 20, true)])
            ))
        }

        let start = BooleanWorldState.facts([(7 % 20, false)])
        let goal = BooleanWorldState.facts([(7 % 20, true)])
        let planner = GOAPPlanner<BooleanWorldState>()

        measure {
            for _ in 0..<100 {
                _ = planner.plan(from: start, goal: goal, actions: actions)
            }
        }
    }

    /// Numeric resource gathering — RichWorldState's hash/equality runs over
    /// dictionary contents, so this is the slower path.
    func testRichWorldStateNumericPlan() {
        let drink = BasicAction<RichWorldState>(
            name: "drink",
            cost: 1,
            preconditions: ["potions": .greaterThan(0)],
            effects: ["health": .add(20), "potions": .subtract(1)]
        )

        let start = RichWorldState(["health": 10, "potions": 10])
        let goal: [String: StateCondition] = ["health": .greaterThanOrEqual(100)]
        let planner = GOAPPlanner<RichWorldState>()

        measure {
            for _ in 0..<100 {
                _ = planner.plan(from: start, goal: goal, actions: [drink])
            }
        }
    }
}
