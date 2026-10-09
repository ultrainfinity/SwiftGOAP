import XCTest
@testable import SwiftGOAP

final class HierarchicalPlanningTests: XCTestCase {

    typealias Prim = BasicAction<BooleanWorldState>
    typealias Step = GOAPHierarchicalPlan<Prim>.Step

    // Facts: 0=hasGun, 1=gunLoaded, 2=enemyDead, 3=atCover, 4=reported
    private func fact(_ pairs: [(Int, Bool)]) -> BooleanWorldState {
        BooleanWorldState.facts(pairs)
    }

    private let pickup = Prim(
        name: "pickupGun",
        preconditions: BooleanWorldState.facts([(0, false)]),
        effects: BooleanWorldState.facts([(0, true)])
    )
    private let load = Prim(
        name: "loadGun",
        preconditions: BooleanWorldState.facts([(0, true), (1, false)]),
        effects: BooleanWorldState.facts([(1, true)])
    )
    private let shoot = Prim(
        name: "shootEnemy",
        preconditions: BooleanWorldState.facts([(0, true), (1, true)]),
        effects: BooleanWorldState.facts([(1, false), (2, true)])
    )
    private let takeCover = Prim(
        name: "takeCover",
        preconditions: BooleanWorldState.facts([(3, false)]),
        effects: BooleanWorldState.facts([(3, true)])
    )
    private let radioIn = Prim(
        name: "radioIn",
        preconditions: BooleanWorldState.facts([(2, true)]),
        effects: BooleanWorldState.facts([(4, true)])
    )

    /// "engage": the enemy ends up dead, however the gun gets ready.
    private func engage(cost: Int = 3, children: [GOAPTask<Prim>]? = nil) -> GOAPSubPlanner<Prim> {
        GOAPSubPlanner(
            name: "engage",
            cost: cost,
            preconditions: BooleanWorldState.facts([(3, true)]),
            effects: BooleanWorldState.facts([(2, true)]),
            children: children ?? [.primitive(pickup), .primitive(load), .primitive(shoot)]
        )
    }

    private let allClear = BooleanWorldState.facts([
        (0, false), (1, false), (2, false), (3, false), (4, false),
    ])

    private let planner = GOAPPlanner<BooleanWorldState>()

    /// "p:name" for primitive steps, "s:name" for sub-plans.
    private func shape(_ plan: GOAPHierarchicalPlan<Prim>) -> [String] {
        plan.steps.map {
            switch $0 {
            case .primitive(let action): return "p:" + action.name
            case .subPlan(let sub, _):   return "s:" + sub.name
            }
        }
    }

    private func agentTasks() -> [GOAPTask<Prim>] {
        [.primitive(takeCover), .subPlanner(engage()), .primitive(radioIn)]
    }

    private func solve(
        _ tasks: [GOAPTask<Prim>],
        goal: BooleanWorldState = BooleanWorldState.facts([(4, true)]),
        from start: BooleanWorldState? = nil,
        maxDepth: Int = 16
    ) -> Result<GOAPHierarchicalPlan<Prim>, GOAPHierarchyError> {
        planner.planHierarchically(from: start ?? allClear, goal: goal, tasks: tasks, maxDepth: maxDepth)
    }

    // MARK: - conditions(pinning:)

    func testBooleanPinningKeepsMaskAndBits() {
        let after = fact([(0, true), (1, false), (2, true)])
        let effects = fact([(1, true), (2, true)])
        let pinned = after.conditions(pinning: effects)
        XCTAssertEqual(pinned.mask, effects.mask)
        XCTAssertEqual(pinned.get(1), false)
        XCTAssertEqual(pinned.get(2), true)
        XCTAssertNil(pinned.get(0))
    }

    func testRichPinningSetBecomesEquals() {
        // The pinned value comes from self, not from the effect's payload, and
        // facts outside the effects are not constrained.
        let before = RichWorldState(["door": "closed", "alarm": false])
        let effects: [String: StateEffect] = ["door": .set("open")]
        XCTAssertEqual(before.conditions(pinning: effects), ["door": .equals("closed")])
        XCTAssertEqual(before.applying(effects).conditions(pinning: effects), ["door": .equals("open")])
    }

    func testRichPinningAddBecomesAbsoluteValue() {
        // Ammo 5 with an "add 2" effect: the state after has 7, so the pinned
        // condition is "ammo equals 7", not "ammo increased by 2".
        let start = RichWorldState(["ammo": 5])
        let effects: [String: StateEffect] = ["ammo": .add(2)]
        let pinned = start.applying(effects).conditions(pinning: effects)
        XCTAssertEqual(pinned, ["ammo": .equals(7)])
    }

    // MARK: - Sub-planner goals

    func testDefaultSubGoalIsPinnedEffects() {
        let goal = engage().subGoal(from: allClear)
        XCTAssertEqual(goal.mask, fact([(2, true)]).mask)
        XCTAssertEqual(goal.get(2), true)
    }

    func testCustomSubGoalOverridesDefault() {
        let careful = GOAPSubPlanner<Prim>(
            name: "engageAndRelease",
            preconditions: BooleanWorldState(),
            effects: fact([(2, true)]),
            children: [.primitive(pickup), .primitive(load), .primitive(shoot)],
            subGoal: { _ in BooleanWorldState.facts([(2, true), (1, false)]) }
        )
        let goal = careful.subGoal(from: allClear)
        XCTAssertEqual(goal.get(1), false)
        XCTAssertEqual(goal.get(2), true)
    }

    // MARK: - refine

    func testRefineFromEmptyHanded() {
        let plan = planner.refine(engage(), from: fact([(0, false), (1, false), (2, false), (3, true)]))
        XCTAssertEqual(plan?.actions.map(\.name), ["pickupGun", "loadGun", "shootEnemy"])
    }

    func testRefineFromLoadedGunOnlyShoots() {
        let plan = planner.refine(engage(), from: fact([(0, true), (1, true), (2, false), (3, true)]))
        XCTAssertEqual(plan?.actions.map(\.name), ["shootEnemy"])
    }

    func testRefineReturnsNilWhenChildrenFallShort() {
        let plan = planner.refine(
            engage(children: [.primitive(pickup), .primitive(load)]),
            from: allClear
        )
        XCTAssertNil(plan)
    }

    func testRefineRelativeEffectIsRelativeToStart() {
        let restock = GOAPSubPlanner<BasicAction<RichWorldState>>(
            name: "restock",
            preconditions: [:],
            effects: ["ammo": .add(2)],
            children: [.primitive(BasicAction(
                name: "loadMagazine",
                preconditions: [:],
                effects: ["ammo": .add(1)]
            ))]
        )
        let richPlanner = GOAPPlanner<RichWorldState>()
        XCTAssertEqual(
            richPlanner.refine(restock, from: RichWorldState(["ammo": 5]))?.states.last,
            RichWorldState(["ammo": 7])
        )
        XCTAssertEqual(
            richPlanner.refine(restock, from: RichWorldState(["ammo": 1]))?.actions.count,
            2
        )
    }

    // MARK: - planHierarchically

    func testAgentScenarioStructure() throws {
        let plan = try solve(agentTasks()).get()

        XCTAssertEqual(shape(plan), ["p:takeCover", "s:engage", "p:radioIn"])
        XCTAssertEqual(plan.states.count, plan.steps.count + 1)
        XCTAssertEqual(plan.states.first, allClear)
        XCTAssertTrue(plan.states.last!.satisfies(fact([(4, true)])))

        guard case .subPlan(_, let inner) = plan.steps[1] else { return XCTFail("expected a sub-plan") }
        XCTAssertEqual(shape(inner), ["p:pickupGun", "p:loadGun", "p:shootEnemy"])
        XCTAssertEqual(inner.states.count, inner.steps.count + 1)
        XCTAssertEqual(plan.states[2], inner.states.last)
    }

    func testFlattenedOrderAndTrajectory() throws {
        let flat = try solve(agentTasks()).get().flattened

        XCTAssertEqual(
            flat.actions.map(\.name),
            ["takeCover", "pickupGun", "loadGun", "shootEnemy", "radioIn"]
        )
        XCTAssertEqual(flat.states.count, flat.actions.count + 1)
        for i in 0..<flat.actions.count {
            XCTAssertEqual(flat.states[i + 1], flat.states[i].applying(flat.actions[i].effects))
        }
    }

    func testNestedSubPlanners() throws {
        // assault → approach, engage (itself a sub-planner), seize
        let approach = Prim(
            name: "approach",
            preconditions: fact([(3, false)]),
            effects: fact([(3, true)])
        )
        let seize = Prim(
            name: "seize",
            preconditions: fact([(2, true)]),
            effects: fact([(4, true)])
        )
        let assault = GOAPSubPlanner<Prim>(
            name: "assault",
            cost: 9,
            preconditions: BooleanWorldState(),
            effects: fact([(4, true)]),
            children: [.primitive(approach), .subPlanner(engage()), .primitive(seize)]
        )
        let plan = try solve([.subPlanner(assault)]).get()

        XCTAssertEqual(shape(plan), ["s:assault"])
        guard case .subPlan(_, let level1) = plan.steps[0] else { return XCTFail("expected a sub-plan") }
        XCTAssertEqual(shape(level1), ["p:approach", "s:engage", "p:seize"])
        guard case .subPlan(_, let level2) = level1.steps[1] else { return XCTFail("expected a sub-plan") }
        XCTAssertEqual(shape(level2), ["p:pickupGun", "p:loadGun", "p:shootEnemy"])
        XCTAssertEqual(
            plan.flattened.actions.map(\.name),
            ["approach", "pickupGun", "loadGun", "shootEnemy", "seize"]
        )
    }

    func testFlattenedTotalCostSumsPrimitiveCosts() throws {
        // takeCover 1 + pickup 1 + load 1 + shoot 1 + radio 1 = 5, whereas the
        // declared cost of "engage" is 10 (the level would sum to 12).
        let tasks: [GOAPTask<Prim>] = [.primitive(takeCover), .subPlanner(engage(cost: 10)), .primitive(radioIn)]
        let plan = try solve(tasks).get()
        XCTAssertEqual(plan.flattened.totalCost, 5)
    }

    func testFlattenedTotalCostUsesDynamicPrimitiveCost() throws {
        // Walking is cheap in cover and expensive in the open.
        struct Walk: GOAPAction {
            let name = "walk"
            let cost = 1
            let preconditions = BooleanWorldState.facts([(4, false)])
            let effects = BooleanWorldState.facts([(4, true)])
            func cost(in state: BooleanWorldState) -> Int { state.get(3) == true ? 2 : 7 }
        }
        let tasks: [GOAPTask<Walk>] = [.primitive(Walk())]
        let result = planner.planHierarchically(
            from: allClear,
            goal: BooleanWorldState.facts([(4, true)]),
            tasks: tasks
        )
        XCTAssertEqual(try result.get().flattened.totalCost, 7)
    }

    func testGoalAlreadySatisfiedYieldsEmptyPlan() throws {
        let start = fact([(0, false), (1, false), (2, false), (3, false), (4, true)])
        let plan = try solve(agentTasks(), from: start).get()
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertEqual(plan.states, [start])
        XCTAssertTrue(plan.flattened.isEmpty)
    }

    func testDeterministicAcrossRepeatedCalls() throws {
        let expected = try solve(agentTasks()).get().flattened.actions.map(\.name)
        for _ in 0..<20 {
            XCTAssertEqual(try solve(agentTasks()).get().flattened.actions.map(\.name), expected)
        }
    }

    // MARK: - Errors

    func testNoPlanAtTopLevel() {
        let result = solve([.primitive(takeCover)])
        XCTAssertEqual(result.failure, .noPlan)
    }

    func testRefinementFailedNamesSubPlannerAndDepth() {
        // The children can arm the gun but never fire it.
        let tasks: [GOAPTask<Prim>] = [
            .primitive(takeCover),
            .subPlanner(engage(children: [.primitive(pickup), .primitive(load)])),
            .primitive(radioIn),
        ]
        XCTAssertEqual(solve(tasks).failure, .refinementFailed(subPlanner: "engage", depth: 1))
    }

    func testRefinementFailedAtDepthTwo() {
        // outer → takeCover, engage (children fall short), radioIn
        let outer = GOAPSubPlanner<Prim>(
            name: "outer",
            preconditions: BooleanWorldState(),
            effects: fact([(4, true)]),
            children: [
                .primitive(takeCover),
                .subPlanner(engage(children: [.primitive(pickup), .primitive(load)])),
                .primitive(radioIn),
            ]
        )
        XCTAssertEqual(
            solve([.subPlanner(outer)]).failure,
            .refinementFailed(subPlanner: "engage", depth: 2)
        )
    }

    func testInconsistentAtNestedLevel() {
        let outer = GOAPSubPlanner<Prim>(
            name: "outer",
            preconditions: BooleanWorldState(),
            effects: fact([(4, true)]),
            children: [.primitive(takeCover), .subPlanner(engage()), .primitive(sneakPast)]
        )
        XCTAssertEqual(
            solve([.subPlanner(outer)]).failure,
            .inconsistent(after: "engage", depth: 1)
        )
    }

    func testMaxDepthZeroAllowsPrimitiveOnlyPlan() throws {
        // radioIn needs the enemy dead, so shooting comes first.
        let tasks: [GOAPTask<Prim>] = [
            .primitive(pickup), .primitive(load), .primitive(shoot), .primitive(radioIn),
        ]
        let plan = try solve(tasks, maxDepth: 0).get()
        XCTAssertEqual(plan.flattened.actions.map(\.name), ["pickupGun", "loadGun", "shootEnemy", "radioIn"])
    }

    // "sneakPast" needs empty hands, but engage's children pick the gun up
    // even though its declared effects never mention it.
    private let sneakPast = Prim(
        name: "sneakPast",
        preconditions: BooleanWorldState.facts([(0, false), (2, true)]),
        effects: BooleanWorldState.facts([(4, true)])
    )

    func testInconsistentWhenChildrenBreakNextPrecondition() {
        let tasks: [GOAPTask<Prim>] = [
            .primitive(takeCover), .subPlanner(engage()), .primitive(sneakPast),
        ]
        XCTAssertEqual(solve(tasks).failure, .inconsistent(after: "engage", depth: 0))
    }

    func testInconsistentWhenLevelGoalIsMissed() {
        // The level's goal wants empty hands, which engage's declared effects
        // leave alone but its children give up by picking the gun up.
        let goal = fact([(2, true), (0, false)])
        let tasks: [GOAPTask<Prim>] = [.primitive(takeCover), .subPlanner(engage())]
        XCTAssertEqual(solve(tasks, goal: goal).failure, .inconsistent(after: "engage", depth: 0))
    }

    func testDepthExceededWhenNoExpansionAllowed() {
        XCTAssertEqual(
            solve(agentTasks(), maxDepth: 0).failure,
            .depthExceeded(subPlanner: "engage")
        )
    }

    func testDepthExceededForChainDeeperThanMaxDepth() {
        let inner = GOAPSubPlanner<Prim>(
            name: "inner",
            preconditions: BooleanWorldState(),
            effects: fact([(4, true)]),
            children: [.primitive(radioInForced)]
        )
        let middle = GOAPSubPlanner<Prim>(
            name: "middle",
            preconditions: BooleanWorldState(),
            effects: fact([(4, true)]),
            children: [.subPlanner(inner)]
        )
        let outer = GOAPSubPlanner<Prim>(
            name: "outer",
            preconditions: BooleanWorldState(),
            effects: fact([(4, true)]),
            children: [.subPlanner(middle)]
        )
        XCTAssertNotNil(try? solve([.subPlanner(outer)], maxDepth: 3).get())
        XCTAssertEqual(
            solve([.subPlanner(outer)], maxDepth: 1).failure,
            .depthExceeded(subPlanner: "middle")
        )
    }

    private let radioInForced = Prim(
        name: "radioInForced",
        preconditions: BooleanWorldState(),
        effects: BooleanWorldState.facts([(4, true)])
    )
}

private extension Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
