import XCTest
@testable import SwiftGOAP

final class GOAPPlannerTests: XCTestCase {

    // MARK: - Combat scenario (boolean state)

    func testCombatPlan() {
        // Facts: 0=hasGun, 1=gunLoaded, 2=enemyDead
        let pickup = BasicAction<BooleanWorldState>(
            name: "pickupGun",
            preconditions: BooleanWorldState.facts([(0, false)]),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let load = BasicAction<BooleanWorldState>(
            name: "loadGun",
            preconditions: BooleanWorldState.facts([(0, true), (1, false)]),
            effects: BooleanWorldState.facts([(1, true)])
        )
        let shoot = BasicAction<BooleanWorldState>(
            name: "shootEnemy",
            preconditions: BooleanWorldState.facts([(0, true), (1, true)]),
            effects: BooleanWorldState.facts([(1, false), (2, true)])
        )
        let actions = [pickup, load, shoot]

        let start = BooleanWorldState.facts([(0, false), (1, false), (2, false)])
        let goal = BooleanWorldState.facts([(2, true)])

        let planner = GOAPPlanner<BooleanWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: actions)

        XCTAssertNotNil(plan)
        XCTAssertEqual(plan?.actions.map(\.name), ["pickupGun", "loadGun", "shootEnemy"])
    }

    // MARK: - Resource gathering (rich state with numeric)

    func testResourceGathering() {
        let buyAxe = BasicAction<RichWorldState>(
            name: "buyAxe",
            cost: 2,
            preconditions: ["hasAxe": .equals(false)],
            effects: ["hasAxe": .set(true)]
        )
        let chop = BasicAction<RichWorldState>(
            name: "chopTree",
            cost: 1,
            preconditions: ["hasAxe": .equals(true)],
            effects: ["wood": .add(1)]
        )
        let actions = [buyAxe, chop]

        let start = RichWorldState(["hasAxe": false, "wood": 0])
        let goal: [String: StateCondition] = ["wood": .greaterThanOrEqual(3)]

        let planner = GOAPPlanner<RichWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: actions)

        XCTAssertEqual(plan?.actions.map(\.name), ["buyAxe", "chopTree", "chopTree", "chopTree"])
    }

    // MARK: - Impossible plan

    func testImpossiblePlanReturnsNil() {
        // Goal needs fact 0 to be true, but no action sets fact 0.
        let useless = BasicAction<BooleanWorldState>(
            name: "useless",
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(1, true)])
        )
        let start = BooleanWorldState.facts([(0, false)])
        let goal = BooleanWorldState.facts([(0, true)])

        let planner = GOAPPlanner<BooleanWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: [useless])

        XCTAssertNil(plan)
    }

    func testNoActionsReturnsNil() {
        let start = BooleanWorldState.facts([(0, false)])
        let goal = BooleanWorldState.facts([(0, true)])
        let planner = GOAPPlanner<BooleanWorldState>()
        XCTAssertNil(planner.plan(from: start, goal: goal, actions: [BasicAction<BooleanWorldState>]()))
    }

    // MARK: - Edge cases

    func testAlreadyAtGoalReturnsEmptyPlan() {
        let start = BooleanWorldState.facts([(0, true)])
        let goal = BooleanWorldState.facts([(0, true)])
        let planner = GOAPPlanner<BooleanWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: [BasicAction<BooleanWorldState>]())
        XCTAssertEqual(plan?.count, 0)
    }

    func testSingleActionPlan() {
        let flip = BasicAction<BooleanWorldState>(
            name: "flip",
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let start = BooleanWorldState.facts([(0, false)])
        let goal = BooleanWorldState.facts([(0, true)])
        let planner = GOAPPlanner<BooleanWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: [flip])
        XCTAssertEqual(plan?.actions.map(\.name), ["flip"])
    }

    func testCheaperPlanIsPreferred() {
        // Two routes from fact 0=false to fact 1=true:
        //   expensive: oneShot (cost 10)
        //   cheap:     twoStep (cost 1) → finish (cost 1)
        let oneShot = BasicAction<BooleanWorldState>(
            name: "oneShot",
            cost: 10,
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(1, true)])
        )
        let twoStepA = BasicAction<BooleanWorldState>(
            name: "twoStepA",
            cost: 1,
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let twoStepB = BasicAction<BooleanWorldState>(
            name: "twoStepB",
            cost: 1,
            preconditions: BooleanWorldState.facts([(0, true)]),
            effects: BooleanWorldState.facts([(1, true)])
        )

        let start = BooleanWorldState.facts([(0, false), (1, false)])
        let goal = BooleanWorldState.facts([(1, true)])

        let planner = GOAPPlanner<BooleanWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: [oneShot, twoStepA, twoStepB])

        XCTAssertEqual(plan?.actions.map(\.name), ["twoStepA", "twoStepB"])
    }

    // MARK: - Multi-goal selection

    func testHighestPriorityAchievableGoalWins() {
        // Two goals:
        //   "kill_dragon" priority 10 — impossible (no action grants it)
        //   "eat_food"    priority 1  — achievable
        let eat = BasicAction<BooleanWorldState>(
            name: "eat",
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(0, true)])
        )

        let start = BooleanWorldState.facts([(0, false), (1, false)])

        let killDragon = GOAPGoal<BooleanWorldState>(
            name: "killDragon",
            conditions: BooleanWorldState.facts([(1, true)]),
            priority: 10
        )
        let eatFood = GOAPGoal<BooleanWorldState>(
            name: "eatFood",
            conditions: BooleanWorldState.facts([(0, true)]),
            priority: 1
        )

        let planner = GOAPPlanner<BooleanWorldState>()
        let result = planner.plan(from: start, goals: [killDragon, eatFood], actions: [eat])

        XCTAssertEqual(result?.goal.name, "eatFood")
        XCTAssertEqual(result?.plan.actions.map(\.name), ["eat"])
        XCTAssertEqual(result?.plan.totalCost, 1)
    }

    func testHigherPriorityWinsWhenBothAchievable() {
        let eat = BasicAction<BooleanWorldState>(
            name: "eat",
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let sleep = BasicAction<BooleanWorldState>(
            name: "sleep",
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(1, true)])
        )

        let start = BooleanWorldState.facts([(0, false), (1, false)])

        let eatGoal = GOAPGoal<BooleanWorldState>(
            name: "eat",
            conditions: BooleanWorldState.facts([(0, true)]),
            priority: 1
        )
        let sleepGoal = GOAPGoal<BooleanWorldState>(
            name: "sleep",
            conditions: BooleanWorldState.facts([(1, true)]),
            priority: 5
        )

        let planner = GOAPPlanner<BooleanWorldState>()
        let result = planner.plan(from: start, goals: [eatGoal, sleepGoal], actions: [eat, sleep])

        XCTAssertEqual(result?.goal.name, "sleep")
    }

    // MARK: - Numeric goal needing several iterations

    func testHealUntilFull() {
        // Start at health 20, goal health >= 100. Drinking a potion heals 30.
        // Optimal: 3 potions (2 leaves us at 80, need a 3rd).
        let drinkPotion = BasicAction<RichWorldState>(
            name: "drinkPotion",
            cost: 1,
            preconditions: ["potions": .greaterThan(0)],
            effects: ["health": .add(30), "potions": .subtract(1)]
        )

        let start = RichWorldState(["health": 20, "potions": 5])
        let goal: [String: StateCondition] = ["health": .greaterThanOrEqual(100)]

        let planner = GOAPPlanner<RichWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: [drinkPotion])

        XCTAssertEqual(plan?.count, 3)
        XCTAssertEqual(plan?.actions.map(\.name), ["drinkPotion", "drinkPotion", "drinkPotion"])
    }

    // MARK: - Plan execution sanity

    func testExecutingPlanReachesGoal() {
        let pickup = BasicAction<BooleanWorldState>(
            name: "pickup",
            preconditions: BooleanWorldState.facts([(0, false)]),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let load = BasicAction<BooleanWorldState>(
            name: "load",
            preconditions: BooleanWorldState.facts([(0, true), (1, false)]),
            effects: BooleanWorldState.facts([(1, true)])
        )
        let shoot = BasicAction<BooleanWorldState>(
            name: "shoot",
            preconditions: BooleanWorldState.facts([(0, true), (1, true)]),
            effects: BooleanWorldState.facts([(1, false), (2, true)])
        )

        let start = BooleanWorldState.facts([(0, false), (1, false), (2, false)])
        let goal = BooleanWorldState.facts([(2, true)])

        let planner = GOAPPlanner<BooleanWorldState>()
        guard let plan = planner.plan(from: start, goal: goal, actions: [pickup, load, shoot]) else {
            XCTFail("expected a plan")
            return
        }

        var state = start
        for action in plan.actions {
            XCTAssertTrue(state.satisfies(action.preconditions), "precondition failed for \(action.name)")
            state = state.applying(action.effects)
        }
        XCTAssertTrue(state.satisfies(goal))

        // Trajectory in plan.states matches what we computed by manual replay.
        XCTAssertEqual(plan.states.last, state)
        XCTAssertEqual(plan.states.count, plan.actions.count + 1)
    }

    // MARK: - GOAPPlan value type

    func testPlanCarriesTotalCostAndStates() {
        // Two-step plan with action costs 2 and 3 → totalCost 5.
        let a = BasicAction<BooleanWorldState>(
            name: "a",
            cost: 2,
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let b = BasicAction<BooleanWorldState>(
            name: "b",
            cost: 3,
            preconditions: BooleanWorldState.facts([(0, true)]),
            effects: BooleanWorldState.facts([(1, true)])
        )

        let start = BooleanWorldState.facts([(0, false), (1, false)])
        let goal = BooleanWorldState.facts([(1, true)])

        let planner = GOAPPlanner<BooleanWorldState>()
        guard let plan = planner.plan(from: start, goal: goal, actions: [a, b]) else {
            XCTFail("expected a plan")
            return
        }

        XCTAssertEqual(plan.totalCost, 5)
        XCTAssertEqual(plan.count, 2)
        XCTAssertFalse(plan.isEmpty)

        // states[0] is start; states[i+1] equals states[i].applying(actions[i].effects)
        XCTAssertEqual(plan.states.first, start)
        XCTAssertEqual(plan.states.count, plan.actions.count + 1)
        for (i, action) in plan.actions.enumerated() {
            XCTAssertEqual(plan.states[i + 1], plan.states[i].applying(action.effects))
        }
    }

    func testEmptyPlanWhenStartSatisfiesGoal() {
        let start = BooleanWorldState.facts([(0, true)])
        let goal = BooleanWorldState.facts([(0, true)])
        let planner = GOAPPlanner<BooleanWorldState>()
        guard let plan = planner.plan(from: start, goal: goal, actions: [BasicAction<BooleanWorldState>]()) else {
            XCTFail("expected an empty plan")
            return
        }
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.totalCost, 0)
        XCTAssertEqual(plan.states, [start])
    }

    // MARK: - Type-safe enum facts

    func testEnumFactOverloads() {
        enum Fact: Int { case hasGun, gunLoaded, enemyDead }

        let pickup = BasicAction<BooleanWorldState>(
            name: "pickup",
            preconditions: BooleanWorldState.facts([(Fact.hasGun, false)]),
            effects: BooleanWorldState.facts([(Fact.hasGun, true)])
        )
        let load = BasicAction<BooleanWorldState>(
            name: "load",
            preconditions: BooleanWorldState.facts([(Fact.hasGun, true), (Fact.gunLoaded, false)]),
            effects: BooleanWorldState.facts([(Fact.gunLoaded, true)])
        )
        let shoot = BasicAction<BooleanWorldState>(
            name: "shoot",
            preconditions: BooleanWorldState.facts([(Fact.hasGun, true), (Fact.gunLoaded, true)]),
            effects: BooleanWorldState.facts([(Fact.gunLoaded, false), (Fact.enemyDead, true)])
        )

        var start = BooleanWorldState()
        start.set(Fact.hasGun, to: false)
        start.set(Fact.gunLoaded, to: false)
        start.set(Fact.enemyDead, to: false)

        let goal = BooleanWorldState.facts([(Fact.enemyDead, true)])

        let planner = GOAPPlanner<BooleanWorldState>()
        let plan = planner.plan(from: start, goal: goal, actions: [pickup, load, shoot])
        XCTAssertEqual(plan?.actions.map(\.name), ["pickup", "load", "shoot"])
        XCTAssertEqual(plan?.states.last?.get(Fact.enemyDead), true)
    }

    // MARK: - maxNodes guard

    func testMaxNodesGuard() {
        // Force the planner to give up by setting maxNodes to 0.
        let pickup = BasicAction<BooleanWorldState>(
            name: "pickup",
            preconditions: BooleanWorldState.facts([(0, false)]),
            effects: BooleanWorldState.facts([(0, true)])
        )
        let start = BooleanWorldState.facts([(0, false), (1, false)])
        let goal = BooleanWorldState.facts([(1, true)])

        var planner = GOAPPlanner<BooleanWorldState>()
        planner.maxNodes = 0
        let plan = planner.plan(from: start, goal: goal, actions: [pickup])
        XCTAssertNil(plan)
    }
}
