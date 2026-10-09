# SwiftGOAP

[![CI](https://github.com/ultrainfinity/SwiftGOAP/actions/workflows/ci.yml/badge.svg)](https://github.com/ultrainfinity/SwiftGOAP/actions/workflows/ci.yml)

Goal-Oriented Action Planning for Swift. Pure Swift, zero dependencies, cross-platform, Sendable-ready.

## What is GOAP?

GOAP (Goal-Oriented Action Planning) is an AI planning technique introduced by Jeff Orkin for *F.E.A.R.* You describe the world as a set of facts, your agent's goals as facts that should become true, and your agent's actions as preconditions plus effects. The planner then runs A\* search over world states to find the cheapest sequence of actions that takes the agent from "now" to "goal" — automatically, at runtime.

That means you can change the world, add new actions, or shift the agent's goals, and behaviour adapts without rewriting branching logic. It is the antithesis of a hand-authored finite-state machine.

## Features

- **Pure Swift, zero dependencies.** No UIKit, SpriteKit, GameplayKit, or Foundation.
- **Cross-platform.** Works on iOS, macOS, tvOS, watchOS, and Linux.
- **Sendable everywhere.** All public types conform to `Sendable` — ready for Swift 6 strict concurrency.
- **Two world-state representations.**
  - `BooleanWorldState` — 64 boolean facts in a single `UInt64`. O(1) compares, O(1) updates, ideal for performance-critical agents.
  - `RichWorldState` — `[String: StateValue]` with bool / int / double / string values, supporting numeric conditions (`>=`, `<`, etc.) and effects (`add`, `subtract`).
- **A\* planner** with closed-set optimisation, optimal-cost search, and a configurable expansion cap.
- **Hierarchical planning.** Composite actions (`GOAPSubPlanner`) that are an action and a planner at once — a single step at the top level, a sub-plan of `GOAPTask` children beneath, with the sub-goal defaulting to the composite's own `effects`. Expand lazily with `refine` as execution reaches each composite, or the whole tree up front with `planHierarchically`.
- **`GOAPPlan` value type** carrying the action sequence, total cost, and the full trajectory of intermediate states.
- **Type-safe facts.** `BooleanWorldState` accepts any `RawRepresentable` whose `RawValue` is `Int`, so you can use enums instead of magic indices.
- **Multi-goal support** with `.priority` (first-achievable) or `.maxUtility` (best `priority - cost`) selection strategies.
- **Dynamic action cost.** Override `cost(in: State)` to let action weight depend on the world ("travel to X" varies by distance).
- **Dynamic action sets.** Pass `actionsFor: (State) -> [Action]` instead of a static array — generate parameterised actions ("go to room R") at planning time.

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/ultrainfinity/SwiftGOAP.git", from: "0.1.0")
```

Then depend on the `SwiftGOAP` product:

```swift
.target(name: "MyGame", dependencies: ["SwiftGOAP"])
```

## Quick start: combat AI with `BooleanWorldState`

A simple agent that picks up a gun, loads it, and shoots an enemy. Facts are an enum, so you never deal with raw bit indices.

```swift
import SwiftGOAP

enum Fact: Int { case hasGun, gunLoaded, enemyDead }

let pickupGun = BasicAction<BooleanWorldState>(
    name: "pickupGun",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, false)]),
    effects:       BooleanWorldState.facts([(Fact.hasGun, true)])
)

let loadGun = BasicAction<BooleanWorldState>(
    name: "loadGun",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, true), (Fact.gunLoaded, false)]),
    effects:       BooleanWorldState.facts([(Fact.gunLoaded, true)])
)

let shootEnemy = BasicAction<BooleanWorldState>(
    name: "shootEnemy",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, true), (Fact.gunLoaded, true)]),
    effects:       BooleanWorldState.facts([(Fact.gunLoaded, false), (Fact.enemyDead, true)])
)

let start = BooleanWorldState.facts([
    (Fact.hasGun, false), (Fact.gunLoaded, false), (Fact.enemyDead, false)
])
let goal = BooleanWorldState.facts([(Fact.enemyDead, true)])

let planner = GOAPPlanner<BooleanWorldState>()
let plan = planner.plan(from: start, goal: goal, actions: [pickupGun, loadGun, shootEnemy])

// plan?.actions.map(\.name) == ["pickupGun", "loadGun", "shootEnemy"]
// plan?.totalCost == 3
// plan?.states.count == 4   // start + 3 intermediate states
```

Add a `repairGun` action and the planner uses it whenever it's the cheapest path. Remove `pickupGun` and the planner returns `nil` instead of a stale FSM transition.

## Numeric goals with `RichWorldState`

Heal until full, using a finite supply of potions:

```swift
let drinkPotion = BasicAction<RichWorldState>(
    name: "drinkPotion",
    cost: 1,
    preconditions: ["potions": .greaterThan(0)],
    effects:       ["health": .add(30), "potions": .subtract(1)]
)

let start = RichWorldState(["health": 20, "potions": 5])
let goal: [String: StateCondition] = ["health": .greaterThanOrEqual(100)]

let planner = GOAPPlanner<RichWorldState>()
let plan = planner.plan(from: start, goal: goal, actions: [drinkPotion])

// plan?.count == 3              // (20 → 50 → 80 → 110)
// plan?.totalCost == 3
```

`StateValue` conforms to the literal protocols, so you can write `["health": 20]` instead of `["health": .integer(20)]`. Conditions support `equals`, `notEquals`, `greaterThan`, `greaterThanOrEqual`, `lessThan`, `lessThanOrEqual`. Effects support `set`, `add`, `subtract`.

> **Note**: `.add` / `.subtract` require an existing numeric value (`.integer` or `.real`). Applying them to a `.bool` / `.text` fact, or to a missing key, traps with a precondition failure — catch this in development, not in production. Use `.set(.integer(0))` first to initialise a counter.

## Multiple goals

Give the agent a list of goals; the planner returns the highest-priority one it can reach, together with the matching plan.

```swift
enum Survival: Int { case fed, armed, enemyDead }

let killEnemy = GOAPGoal<BooleanWorldState>(
    name: "killEnemy",
    conditions: BooleanWorldState.facts([(Survival.enemyDead, true)]),
    priority: 10
)
let eatFood = GOAPGoal<BooleanWorldState>(
    name: "eatFood",
    conditions: BooleanWorldState.facts([(Survival.fed, true)]),
    priority: 1
)

if let result = planner.plan(from: start, goals: [killEnemy, eatFood], actions: actions) {
    print("pursuing \(result.goal.name): \(result.plan.actions.map(\.name))")
}
```

Default behaviour: try goals in descending priority order and return the first that has a plan. Pass `selectingBy: .maxUtility` to instead pick the goal that maximises `priority - plan.totalCost` — useful when an expensive high-priority goal should defer to a cheap low-priority one:

```swift
let result = planner.plan(
    from: start,
    goals: [killEnemy, eatFood],
    actions: actions,
    selectingBy: .maxUtility
)
```

## Custom action types

`BasicAction` is a convenience. Anything that conforms to `GOAPAction` works — you can attach domain-specific behaviour (animation hooks, audio cues, callbacks) directly to your action type. Conform to `Sendable` if you plan to cross actor boundaries.

```swift
struct CombatAction: GOAPAction {
    let name: String
    let cost: Int
    let preconditions: BooleanWorldState
    let effects: BooleanWorldState
    let animation: String
    let perform: @Sendable () -> Void
}
```

The planner returns `GOAPPlan<CombatAction>`, so you keep all that data through to execution.

## Executing a plan

The planner returns the action sequence; running it is up to you.

```swift
guard let plan = planner.plan(from: currentWorldState, goal: goal, actions: actions) else {
    return    // no plan exists right now
}

var state = currentWorldState
for action in plan.actions {
    guard state.satisfies(action.preconditions) else { break }   // world drifted, re-plan
    perform(action)
    state = state.applying(action.effects)
}
```

You can also use `plan.states` directly — it contains the start state, every intermediate state, and the goal-satisfying final state. Handy for visualisation and debugging.

When the world drifts (a door closes, ammo is taken), drop the plan and re-plan from the new state. Re-planning is cheap.

## Hierarchical planning

A flat action set forces every step onto one level: "engage the enemy" is either a single opaque action or a dozen primitives all competing for the planner's attention. A composite action is both at once — an ordinary action to the level that contains it, sequenced by its `preconditions`, `effects`, and `cost`, and a planner of its own when execution reaches it. `GOAPSubPlanner` is the ready-made value type: its `children` are `GOAPTask`s, each either a primitive action or another sub-planner, so hierarchies nest to any depth. Custom composites only need to conform to `GOAPCompositeAction`.

A sub-plan needs a goal, and the default falls out of the action itself: the composite's `effects`, pinned to the values they actually produce — `conditions(pinning:)` turns the declaration "the enemy ends up dead" into an absolute target the children must deliver, whatever route they take. The declared effects are a promise, not a recipe. Pass `subGoal:` to compute a different goal from the starting state.

```swift
typealias Prim = BasicAction<BooleanWorldState>

enum Fact: Int { case hasGun, gunLoaded, enemyDead, atCover, reported }

let pickupGun = Prim(
    name: "pickupGun",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, false)]),
    effects:       BooleanWorldState.facts([(Fact.hasGun, true)])
)
let loadGun = Prim(
    name: "loadGun",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, true), (Fact.gunLoaded, false)]),
    effects:       BooleanWorldState.facts([(Fact.gunLoaded, true)])
)
let shootEnemy = Prim(
    name: "shootEnemy",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, true), (Fact.gunLoaded, true)]),
    effects:       BooleanWorldState.facts([(Fact.gunLoaded, false), (Fact.enemyDead, true)])
)
let takeCover = Prim(
    name: "takeCover",
    preconditions: BooleanWorldState.facts([(Fact.atCover, false)]),
    effects:       BooleanWorldState.facts([(Fact.atCover, true)])
)
let radioIn = Prim(
    name: "radioIn",
    preconditions: BooleanWorldState.facts([(Fact.enemyDead, true)]),
    effects:       BooleanWorldState.facts([(Fact.reported, true)])
)

// One action at this level; a planner of its own beneath.
let engage = GOAPSubPlanner<Prim>(
    name: "engage",
    preconditions: BooleanWorldState.facts([(Fact.atCover, true)]),
    effects:       BooleanWorldState.facts([(Fact.enemyDead, true)]),
    children: [.primitive(pickupGun), .primitive(loadGun), .primitive(shootEnemy)]
)

let start = BooleanWorldState.facts([
    (Fact.hasGun, false), (Fact.gunLoaded, false), (Fact.enemyDead, false),
    (Fact.atCover, false), (Fact.reported, false),
])
let goal = BooleanWorldState.facts([(Fact.reported, true)])

let tasks: [GOAPTask<Prim>] = [
    .primitive(takeCover), .subPlanner(engage), .primitive(radioIn),
]

let result = GOAPPlanner<BooleanWorldState>().planHierarchically(
    from: start,
    goal: goal,
    tasks: tasks
)

let hierarchy = try result.get()
// hierarchy.steps.count == 3   // takeCover, engage (with its own sub-plan), radioIn

let plan = hierarchy.flattened
// plan.actions.map(\.name) == ["takeCover", "pickupGun", "loadGun", "shootEnemy", "radioIn"]
```

`flattened` collapses the hierarchy into the executable `GOAPPlan` of primitives; the unflattened `steps` keep every sub-plan alongside the sub-planner that produced it, and `states` holds the trajectory of states each level actually moves through.

Expanding the whole tree up front is one style; the other is lazy. Because `GOAPTask` conforms to `GOAPAction`, a plain `plan(from:goal:actions:)` accepts a mixed task set and treats each sub-planner as a single step — call `refine(_:from:)` when execution reaches it, and the sub-plan starts from the world as it actually is. `refine` returns `nil` when the children cannot reach the sub-goal. `planHierarchically` reports failure as a `GOAPHierarchyError`: `.noPlan` when the top level has no route to the goal, `.refinementFailed(subPlanner:depth:)` when a sub-plan falls short, `.inconsistent(after:depth:)` when the state an expansion actually reached breaks the next step or the level's goal, and `.depthExceeded(subPlanner:)` when expansion would nest past `maxDepth`.

## Performance notes

- `BooleanWorldState` operations are single 64-bit ALU ops. Plans of 5–10 actions over a dozen action types resolve in tens of microseconds.
- The A\* loop uses a closed set with reopen-on-better-g, so stale frontier entries are discarded immediately instead of re-expanded.
- The `GOAPPlanner.maxNodes` cap (default 10,000) protects against runaway searches if your action set has bad cycles or your heuristic is too weak.
- The default heuristic counts unsatisfied facts. It is fast and produces sensible plans, but is not strictly admissible when one action satisfies multiple facts at once. In rare cases the returned plan may be one action longer than truly optimal — the standard GOAP trade-off.

## Why this exists

There are GOAP implementations in C (stolk/GPGOAP), C++, C# (mountain-goap), Go, Rust, and Python — but until now, none in Swift. This package fills that gap with an idiomatic, dependency-free, Sendable-ready Swift API that works in games, simulations, and any other agent-based system.

## License

MIT. See [LICENSE](LICENSE).

## Further reading

- Jeff Orkin, *Three States and a Plan: The A.I. of F.E.A.R.* — the original GOAP paper.
- [stolk/GPGOAP](https://github.com/stolk/GPGOAP) — minimal C reference.
- [caesuric/mountain-goap](https://github.com/caesuric/mountain-goap) — comprehensive C# implementation.
