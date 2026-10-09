# Hierarchical Planning

Plan in layers: composite actions that are single steps at the top level and full sub-plans beneath.

## Overview

A flat action set forces every step onto one level — "engage the enemy" is either one opaque action or a dozen primitives the top-level search has to wade through. A composite action (``GOAPCompositeAction``) is both at once: to the level that contains it, an ordinary action sequenced by its `preconditions`, `effects`, and `cost`; when execution reaches it, a planner over its own `subActions(in:)`. ``GOAPSubPlanner`` is the ready-made value type. Its `children` are ``GOAPTask``s — each either a primitive action or another `GOAPSubPlanner` — and because `GOAPTask` conforms to `GOAPAction`, primitives and sub-planners sit side by side in one action set, with hierarchies nesting to any depth.

## Composite actions and sub-goals

Every sub-plan aims at `subGoal(from:)`. The default goal is the composite's `effects`, pinned to the values they actually produce in the starting state: `conditions(pinning:)` applied to `state.applying(effects)` turns a relative effect such as "add 3 to ammo" into the absolute target "ammo equals the value reached". The declared `effects` are a promise, not a recipe — the sub-plan may reach the goal by any route, and the state it ends in replaces the state the declaration predicted. Pass `subGoal:` to compute a goal of your own from the starting state.

## Expanding as you go

`GOAPPlanner.refine(_:from:)` plans one composite on demand: a search over its sub-actions towards its sub-goal, from the state the agent is actually in. Because `GOAPTask` conforms to `GOAPAction`, the ordinary `plan(from:goal:actions:)` accepts a mixed task set and treats each sub-planner as a single step; refine each one when the execution loop arrives at it, so every sub-plan starts from the world as it is, not as the declaration predicted.

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

let planner = GOAPPlanner<BooleanWorldState>()
let start = BooleanWorldState.facts([
    (Fact.hasGun, false), (Fact.gunLoaded, false), (Fact.enemyDead, false),
    (Fact.atCover, false), (Fact.reported, false),
])
let goal = BooleanWorldState.facts([(Fact.reported, true)])
let tasks: [GOAPTask<Prim>] = [
    .primitive(takeCover), .subPlanner(engage), .primitive(radioIn),
]

guard let top = planner.plan(from: start, goal: goal, actions: tasks) else {
    return    // no plan exists right now
}

var state = start
for step in top.actions {
    if case .subPlanner(let composite) = step {
        // Execution reached the composite: plan it from the world as it is now.
        guard let subPlan = planner.refine(composite, from: state) else { break }   // children fell short, re-plan
        for primitive in subPlan.actions {
            state = state.applying(primitive.effects)
        }
    } else {
        state = state.applying(step.effects)
    }
}
```

A `nil` from `refine` means the children cannot reach the sub-goal from the state at hand; treat it like any failed plan and re-plan the level above.

## Expanding the whole hierarchy

`GOAPPlanner.planHierarchically(from:goal:tasks:maxDepth:)` expands every sub-planner before returning. Each level is planned with its sub-planners as ordinary actions, then walked in the state the agent would actually be in: a sub-planner expands from that state towards `subGoal(from:)`, and the state its sub-plan reaches carries on to the next step. `maxDepth` bounds how deep an expansion may nest — the top level is 0, so `maxDepth: 0` allows no expansion at all (default 16).

```swift
// With the same task set: expand every sub-planner up front.
let result = planner.planHierarchically(from: start, goal: goal, tasks: tasks)

let hierarchy = try result.get()
// hierarchy.steps.count == 3   // takeCover, engage (with its own sub-plan), radioIn

let plan = hierarchy.flattened
// plan.actions.map(\.name) == ["takeCover", "pickupGun", "loadGun", "shootEnemy", "radioIn"]
```

The returned ``GOAPHierarchicalPlan`` mirrors the hierarchy: each `.subPlan` step carries the `GOAPSubPlanner` together with the plan it expanded into, `states` holds the trajectory of actual states at every level, and `flattened` collapses the tree into an executable ``GOAPPlan`` whose `totalCost` sums the primitives — not the declared costs of the sub-planners that were expanded. Nothing is replanned automatically, so the result is deterministic; for worlds that change as the agent acts, prefer the lazy `refine`.

Failure comes back as a ``GOAPHierarchyError``:

- `.noPlan` — the top level has no route to the goal.
- `.refinementFailed(subPlanner:depth:)` — no sub-plan exists for that sub-planner from the state it was expanded in; `depth` is the level of the sub-plan, with the top level at 0.
- `.inconsistent(after:depth:)` — the state an expansion actually reached no longer satisfies the next step's preconditions, or the level's own goal.
- `.depthExceeded(subPlanner:)` — expanding that sub-planner would nest deeper than `maxDepth`.
