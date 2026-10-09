# ``SwiftGOAP``

Goal-Oriented Action Planning for Swift — pure Swift, zero dependencies, Sendable-ready.

## Overview

SwiftGOAP is an implementation of the GOAP (Goal-Oriented Action Planning) algorithm popularised by Jeff Orkin's work on *F.E.A.R.* You describe the world as a set of facts, your agent's goals as facts that should become true, and your agent's actions as preconditions plus effects. The planner then runs A\* search over world states to find the cheapest sequence of actions that takes the agent from "now" to "goal" — automatically, at runtime.

You change the world, add new actions, or shift the agent's goals, and behaviour adapts. No hand-authored finite-state machine.

Composite actions extend the same model to whole hierarchies: a `GOAPSubPlanner` is a single action to the level that contains it and a planner over its own children beneath it. `planHierarchically(from:goal:tasks:maxDepth:)` expands every sub-plan up front; `refine(_:from:)` defers each expansion until execution reaches it. See <doc:HierarchicalPlanning>.

## Quick start

```swift
import SwiftGOAP

enum Fact: Int { case hasGun, gunLoaded, enemyDead }

let pickup = BasicAction<BooleanWorldState>(
    name: "pickup",
    preconditions: BooleanWorldState.facts([(Fact.hasGun, false)]),
    effects:       BooleanWorldState.facts([(Fact.hasGun, true)])
)
// ...

let plan = GOAPPlanner<BooleanWorldState>().plan(
    from: start,
    goal: BooleanWorldState.facts([(Fact.enemyDead, true)]),
    actions: actions
)
```

The returned ``GOAPPlan`` carries the action sequence, total cost, and the trajectory of intermediate states.

## Topics

### World state

- ``WorldState``
- ``BooleanWorldState``
- ``RichWorldState``
- ``StateValue``
- ``StateCondition``
- ``StateEffect``

### Planning

- ``GOAPAction``
- ``BasicAction``
- ``GOAPGoal``
- ``GOAPPlan``
- ``GOAPPlanner``
- ``GoalSelectionStrategy``

### Hierarchical planning

- ``GOAPCompositeAction``
- ``GOAPSubPlanner``
- ``GOAPTask``
- ``GOAPHierarchicalPlan``
- ``GOAPHierarchyError``
- <doc:HierarchicalPlanning>

### Supporting

- ``PriorityQueue``
