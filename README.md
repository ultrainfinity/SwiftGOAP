# SwiftGOAP

Goal-Oriented Action Planning for Swift. Pure Swift, zero dependencies, cross‑platform.

## What is GOAP?

GOAP (Goal-Oriented Action Planning) is an AI planning technique introduced by Jeff Orkin for *F.E.A.R.* You describe the world as a set of facts, your agent's goals as facts that should become true, and your agent's actions as preconditions plus effects. The planner then runs A\* search over world states to find the cheapest sequence of actions that takes the agent from "now" to "goal" — automatically, at runtime.

That means you can change the world, add new actions, or shift the agent's goals, and behaviour adapts without rewriting branching logic. It is the antithesis of a hand-authored finite-state machine.

## Features

- **Pure Swift, zero dependencies.** No UIKit, SpriteKit, GameplayKit, or Foundation.
- **Cross-platform.** Works on iOS, macOS, tvOS, watchOS, and Linux.
- **Two world-state representations.**
  - `BooleanWorldState` — 64 boolean facts in a single `UInt64`. O(1) compares, O(1) updates, ideal for performance-critical agents.
  - `RichWorldState` — `[String: StateValue]` with bool / int / double / string values, supporting numeric conditions (`>=`, `<`, etc.) and effects (`add`, `subtract`).
- **A\* planner** with optimal-cost search and a configurable expansion cap.
- **Multi-goal support** — the planner picks the highest-priority goal that has a plan.

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

A simple agent that picks up a gun, loads it, and shoots an enemy.

```swift
import SwiftGOAP

// Facts: 0 = hasGun, 1 = gunLoaded, 2 = enemyDead
let pickupGun = BasicAction<BooleanWorldState>(
    name: "pickupGun",
    preconditions: BooleanWorldState.facts([(0, false)]),
    effects:       BooleanWorldState.facts([(0, true)])
)

let loadGun = BasicAction<BooleanWorldState>(
    name: "loadGun",
    preconditions: BooleanWorldState.facts([(0, true), (1, false)]),
    effects:       BooleanWorldState.facts([(1, true)])
)

let shootEnemy = BasicAction<BooleanWorldState>(
    name: "shootEnemy",
    preconditions: BooleanWorldState.facts([(0, true), (1, true)]),
    effects:       BooleanWorldState.facts([(1, false), (2, true)])
)

let start = BooleanWorldState.facts([(0, false), (1, false), (2, false)])
let goal  = BooleanWorldState.facts([(2, true)])

let planner = GOAPPlanner<BooleanWorldState>()
let plan = planner.plan(from: start, goal: goal, actions: [pickupGun, loadGun, shootEnemy])

// plan?.map(\.name) == ["pickupGun", "loadGun", "shootEnemy"]
```

Add a `repairGun` action and the planner will use it whenever it's the cheapest path. Remove `pickupGun` and the planner returns `nil` instead of a stale FSM transition.

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

// plan?.count == 3   // (20 → 50 → 80 → 110)
```

`StateValue` conforms to the literal protocols, so you can write `["health": 20]` instead of `["health": .integer(20)]`. Conditions support `equals`, `notEquals`, `greaterThan`, `greaterThanOrEqual`, `lessThan`, `lessThanOrEqual`. Effects support `set`, `add`, `subtract`.

## Multiple goals, by priority

Give the agent a list of goals; the planner returns the highest-priority one it can reach.

```swift
let killDragon = GOAPGoal<BooleanWorldState>(
    name: "killDragon",
    conditions: BooleanWorldState.facts([(1, true)]),  // probably impossible
    priority: 10
)
let eatFood = GOAPGoal<BooleanWorldState>(
    name: "eatFood",
    conditions: BooleanWorldState.facts([(0, true)]),
    priority: 1
)

let result = planner.plan(from: start, goals: [killDragon, eatFood], actions: actions)
// → (goal: eatFood, plan: [eat])    // dragon-killing falls through; eating wins.
```

## Custom action types

`BasicAction` is a convenience. Anything that conforms to `GOAPAction` works — you can attach domain-specific behaviour (animation hooks, audio cues, callbacks) directly to your action type.

```swift
struct CombatAction: GOAPAction {
    let name: String
    let cost: Int
    let preconditions: BooleanWorldState
    let effects: BooleanWorldState
    let animation: String
    let onPerform: () -> Void
}
```

The planner returns `[CombatAction]` so you keep all that data through to execution.

## Executing a plan

The planner returns the action sequence; running it is up to you.

```swift
var state = currentWorldState
for action in plan {
    guard state.satisfies(action.preconditions) else { break }   // someone changed the world
    perform(action)
    state = state.applying(action.effects)
}
```

When the world drifts (a door closes, ammo is taken), drop the plan and re-plan from the new state. Re-planning is cheap.

## Performance notes

- `BooleanWorldState` operations are single 64-bit ALU ops. Plans of 5–10 actions over a dozen action types resolve in tens of microseconds.
- The `GOAPPlanner.maxNodes` cap (default 10,000) protects against runaway searches if your action set has bad cycles or your heuristic is too weak.
- The default heuristic counts unsatisfied facts. It is fast and produces sensible plans, but is not strictly admissible when one action satisfies multiple facts at once. In rare cases the returned plan may be one action longer than truly optimal — the standard GOAP trade-off.

## Why this exists

There are GOAP implementations in C (stolk/GPGOAP), C++, C# (mountain-goap), Go, Rust, and Python — but until now, none in Swift. This package fills that gap with an idiomatic, dependency-free Swift API that works in games, simulations, and any other agent-based system.

## License

MIT. See [LICENSE](LICENSE).

## Further reading

- Jeff Orkin, *Three States and a Plan: The A.I. of F.E.A.R.* — the original GOAP paper.
- [stolk/GPGOAP](https://github.com/stolk/GPGOAP) — minimal C reference.
- [caesuric/mountain-goap](https://github.com/caesuric/mountain-goap) — comprehensive C# implementation.
