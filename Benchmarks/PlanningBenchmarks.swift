import SwiftGOAP

/// End-to-end planning benchmarks — same logical scenario expressed in both
/// world-state types. This is the apples-to-apples comparison most users
/// actually care about: "for the same problem, how much slower is Rich?"
func runPlanningBenchmarks(into runner: inout BenchmarkRunner) {

    // Scenario A: short F.E.A.R.-style combat plan (3 steps when starting
    // from scratch). Small but hits all the A* machinery.
    let combatBool = combatBooleanScenario()
    let combatRich = combatRichScenario()

    runner.measure("Boolean: F.E.A.R. plan (3 steps)", category: "Planning") {
        Blackhole.observe(
            GOAPPlanner<BooleanWorldState>().plan(
                from: combatBool.start, goal: combatBool.goal, actions: combatBool.actions
            )
        )
    }
    runner.measure("Rich: F.E.A.R. plan (3 steps)", category: "Planning") {
        Blackhole.observe(
            GOAPPlanner<RichWorldState>().plan(
                from: combatRich.start, goal: combatRich.goal, actions: combatRich.actions
            )
        )
    }

    // Scenario B: deeper chained problem — 10 boolean facts, each gated by
    // the previous, producing a 10-step plan. Stresses the planner more.
    let chainBool = chainBooleanScenario(depth: 10)
    let chainRich = chainRichScenario(depth: 10)

    runner.measure("Boolean: chain plan (10 steps)", category: "Planning") {
        Blackhole.observe(
            GOAPPlanner<BooleanWorldState>().plan(
                from: chainBool.start, goal: chainBool.goal, actions: chainBool.actions
            )
        )
    }
    runner.measure("Rich: chain plan (10 steps)", category: "Planning") {
        Blackhole.observe(
            GOAPPlanner<RichWorldState>().plan(
                from: chainRich.start, goal: chainRich.goal, actions: chainRich.actions
            )
        )
    }

    // Scenario C: many candidate actions, shallow plan — exercises the
    // branching factor side of A*. 30 actions, only one path to the goal.
    let wideBool = wideBooleanScenario(numActions: 30)
    let wideRich = wideRichScenario(numActions: 30)

    runner.measure("Boolean: wide-shallow (30 actions)", category: "Planning") {
        Blackhole.observe(
            GOAPPlanner<BooleanWorldState>().plan(
                from: wideBool.start, goal: wideBool.goal, actions: wideBool.actions
            )
        )
    }
    runner.measure("Rich: wide-shallow (30 actions)", category: "Planning") {
        Blackhole.observe(
            GOAPPlanner<RichWorldState>().plan(
                from: wideRich.start, goal: wideRich.goal, actions: wideRich.actions
            )
        )
    }
}

// MARK: - Scenario builders

/// F.E.A.R. combat: pickup → load → shoot.
private func combatBooleanScenario() -> (
    start: BooleanWorldState,
    goal: BooleanWorldState,
    actions: [BasicAction<BooleanWorldState>]
) {
    let actions: [BasicAction<BooleanWorldState>] = [
        BasicAction(name: "pickup",
                    preconditions: BooleanWorldState.facts([(0, false)]),
                    effects:       BooleanWorldState.facts([(0, true)])),
        BasicAction(name: "load",
                    preconditions: BooleanWorldState.facts([(0, true), (1, false)]),
                    effects:       BooleanWorldState.facts([(1, true)])),
        BasicAction(name: "shoot",
                    preconditions: BooleanWorldState.facts([(0, true), (1, true)]),
                    effects:       BooleanWorldState.facts([(2, true), (1, false)])),
    ]
    let start = BooleanWorldState.facts([(0, false), (1, false), (2, false)])
    let goal  = BooleanWorldState.facts([(2, true)])
    return (start, goal, actions)
}

private func combatRichScenario() -> (
    start: RichWorldState,
    goal: [String: StateCondition],
    actions: [BasicAction<RichWorldState>]
) {
    let actions: [BasicAction<RichWorldState>] = [
        BasicAction(name: "pickup",
                    preconditions: ["hasGun": .equals(.bool(false))],
                    effects:       ["hasGun": .set(.bool(true))]),
        BasicAction(name: "load",
                    preconditions: [
                        "hasGun":     .equals(.bool(true)),
                        "gunLoaded":  .equals(.bool(false))
                    ],
                    effects: ["gunLoaded": .set(.bool(true))]),
        BasicAction(name: "shoot",
                    preconditions: [
                        "hasGun":     .equals(.bool(true)),
                        "gunLoaded":  .equals(.bool(true))
                    ],
                    effects: [
                        "enemyDead":  .set(.bool(true)),
                        "gunLoaded":  .set(.bool(false))
                    ]),
    ]
    let start = RichWorldState([
        "hasGun":     .bool(false),
        "gunLoaded":  .bool(false),
        "enemyDead":  .bool(false)
    ])
    let goal: [String: StateCondition] = ["enemyDead": .equals(.bool(true))]
    return (start, goal, actions)
}

/// Chained: each step i requires fact[i] true and produces fact[i+1] true.
private func chainBooleanScenario(depth: Int) -> (
    start: BooleanWorldState,
    goal: BooleanWorldState,
    actions: [BasicAction<BooleanWorldState>]
) {
    var actions: [BasicAction<BooleanWorldState>] = []
    for i in 0..<depth {
        actions.append(BasicAction(
            name: "step\(i)",
            preconditions: i == 0
                ? BooleanWorldState()
                : BooleanWorldState.facts([(i, true)]),
            effects: BooleanWorldState.facts([(i + 1, true)])
        ))
    }
    let start = BooleanWorldState()
    let goal  = BooleanWorldState.facts([(depth, true)])
    return (start, goal, actions)
}

private func chainRichScenario(depth: Int) -> (
    start: RichWorldState,
    goal: [String: StateCondition],
    actions: [BasicAction<RichWorldState>]
) {
    var actions: [BasicAction<RichWorldState>] = []
    for i in 0..<depth {
        let pre: [String: StateCondition] = i == 0
            ? [:]
            : ["f\(i)": .equals(.bool(true))]
        actions.append(BasicAction(
            name: "step\(i)",
            preconditions: pre,
            effects: ["f\(i + 1)": .set(.bool(true))]
        ))
    }
    let start = RichWorldState([:])
    let goal: [String: StateCondition] = ["f\(depth)": .equals(.bool(true))]
    return (start, goal, actions)
}

/// Wide-shallow: many candidate actions, only one with cost 1, the rest
/// cost 100. Tests how quickly A\* discriminates against expensive successors.
private func wideBooleanScenario(numActions: Int) -> (
    start: BooleanWorldState,
    goal: BooleanWorldState,
    actions: [BasicAction<BooleanWorldState>]
) {
    var actions: [BasicAction<BooleanWorldState>] = []
    let winningBit = numActions / 2
    for i in 0..<numActions {
        actions.append(BasicAction(
            name: "a\(i)",
            cost: i == winningBit ? 1 : 100,
            preconditions: BooleanWorldState(),
            effects: BooleanWorldState.facts([(i % 20, true)])
        ))
    }
    let start = BooleanWorldState.facts([(winningBit % 20, false)])
    let goal  = BooleanWorldState.facts([(winningBit % 20, true)])
    return (start, goal, actions)
}

private func wideRichScenario(numActions: Int) -> (
    start: RichWorldState,
    goal: [String: StateCondition],
    actions: [BasicAction<RichWorldState>]
) {
    var actions: [BasicAction<RichWorldState>] = []
    let winningKey = "k\(numActions / 2)"
    for i in 0..<numActions {
        let key = "k\(i % 20)"
        actions.append(BasicAction(
            name: "a\(i)",
            cost: "k\(i)" == winningKey ? 1 : 100,
            preconditions: [:],
            effects: [key: .set(.bool(true))]
        ))
    }
    let goalKey = "k\((numActions / 2) % 20)"
    let start = RichWorldState([goalKey: .bool(false)])
    let goal: [String: StateCondition] = [goalKey: .equals(.bool(true))]
    return (start, goal, actions)
}
