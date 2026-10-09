/// A goal-oriented planner that finds the cheapest action sequence taking a
/// start state to a state satisfying a goal.
///
/// The planner runs A* over states. Each action defines a transition: it is
/// applicable when its preconditions hold, and produces a new state via its
/// effects. The cost of a plan is the sum of action costs.
///
/// The "unsatisfied facts" heuristic used by `WorldState` types in this
/// package is fast and works well in practice, but is not strictly admissible
/// when one action can resolve multiple facts at once. In that case A* may
/// return a non-optimal plan; for typical game scenarios this is the standard
/// trade-off and the resulting plans are still sensible.
public struct GOAPPlanner<State: WorldState>: Sendable {
    /// Cap on the number of states expanded before the planner gives up. This
    /// prevents pathological search trees from running forever.
    public var maxNodes: Int

    public init(maxNodes: Int = 10_000) {
        self.maxNodes = maxNodes
    }

    /// The cheapest plan from `start` that satisfies `goal`, or `nil` if no
    /// plan exists within `maxNodes` expansions. The returned `GOAPPlan`
    /// contains both the action sequence and the trajectory of intermediate
    /// states. An empty plan (`isEmpty == true`) means the start state already
    /// satisfies the goal.
    public func plan<Action: GOAPAction>(
        from start: State,
        goal: State.Conditions,
        actions: [Action]
    ) -> GOAPPlan<Action>? where Action.State == State {
        plan(from: start, goal: goal, actionsFor: { _ in actions })
    }

    /// Same as `plan(from:goal:actions:)`, but actions are generated per-state
    /// by a closure. Use this when the set of applicable actions depends on
    /// the world — e.g. "go to room X" should yield a different action per
    /// reachable room, or a long-lived agent might learn new actions over time.
    ///
    /// The closure is invoked on every node expansion. Keep it cheap; cache
    /// inside the closure if your generation logic is expensive.
    public func plan<Action: GOAPAction>(
        from start: State,
        goal: State.Conditions,
        actionsFor: (State) -> [Action]
    ) -> GOAPPlan<Action>? where Action.State == State {
        if start.satisfies(goal) {
            return GOAPPlan(actions: [], states: [start])
        }

        var gScore: [State: Int] = [start: 0]
        var cameFrom: [State: (predecessor: State, action: Action)] = [:]
        // Set of states already finalized via dequeue. A state can be reopened
        // if a successor relaxation later finds a strictly cheaper path to it,
        // which preserves correctness when the heuristic is inadmissible.
        var closed: Set<State> = []

        var frontier = PriorityQueue<State>()
        frontier.enqueue(start, priority: start.heuristicDistance(to: goal))

        var expansions = 0

        while let current = frontier.dequeue() {
            // Stale frontier entries get skipped here — we already finalized
            // this state (or a strictly cheaper path to it) on a prior dequeue.
            if closed.contains(current) { continue }
            closed.insert(current)

            if current.satisfies(goal) {
                let (acts, states) = reconstruct(target: current, cameFrom: cameFrom)
                return GOAPPlan(actions: acts, states: states)
            }

            expansions += 1
            if expansions > maxNodes { return nil }

            let currentG = gScore[current] ?? .max

            for action in actionsFor(current) {
                guard current.satisfies(action.preconditions) else { continue }
                let stepCost = action.cost(in: current)
                precondition(stepCost >= 0, "action '\(action.name)' has negative cost")

                let next = current.applying(action.effects)
                let tentativeG = currentG + stepCost

                if tentativeG < (gScore[next] ?? .max) {
                    gScore[next] = tentativeG
                    cameFrom[next] = (current, action)
                    // Reopen if we previously closed this state at a worse g.
                    closed.remove(next)
                    let f = tentativeG + next.heuristicDistance(to: goal)
                    frontier.enqueue(next, priority: f)
                }
            }
        }

        return nil
    }

    /// Convenience overload that takes a `GOAPGoal`.
    public func plan<Action: GOAPAction>(
        from start: State,
        goal: GOAPGoal<State>,
        actions: [Action]
    ) -> GOAPPlan<Action>? where Action.State == State {
        plan(from: start, goal: goal.conditions, actions: actions)
    }

    /// Convenience overload combining `GOAPGoal` with a dynamic action source.
    public func plan<Action: GOAPAction>(
        from start: State,
        goal: GOAPGoal<State>,
        actionsFor: (State) -> [Action]
    ) -> GOAPPlan<Action>? where Action.State == State {
        plan(from: start, goal: goal.conditions, actionsFor: actionsFor)
    }

    /// Picks one goal from `goals` and returns it together with a plan that
    /// satisfies it. The selection rule is controlled by `selectingBy`.
    ///
    /// - `.priority` (default): try goals in descending `priority` and return
    ///   the first that has a plan. Cheap — at most one plan is computed per
    ///   goal until the first success.
    /// - `.maxUtility`: compute plans for every goal and return the one
    ///   maximising `priority - plan.totalCost`. More expensive (`O(goals)`
    ///   plans), but lets a cheap low-priority goal win over an expensive
    ///   high-priority one.
    public func plan<Action: GOAPAction>(
        from start: State,
        goals: [GOAPGoal<State>],
        actions: [Action],
        selectingBy strategy: GoalSelectionStrategy = .priority
    ) -> (goal: GOAPGoal<State>, plan: GOAPPlan<Action>)? where Action.State == State {
        switch strategy {
        case .priority:
            let ordered = goals.sorted { $0.priority > $1.priority }
            for goal in ordered {
                if let plan = plan(from: start, goal: goal.conditions, actions: actions) {
                    return (goal, plan)
                }
            }
            return nil

        case .maxUtility:
            var best: (goal: GOAPGoal<State>, plan: GOAPPlan<Action>)? = nil
            var bestScore: Int = .min
            for goal in goals {
                guard let plan = plan(from: start, goal: goal.conditions, actions: actions) else {
                    continue
                }
                let score = goal.priority - plan.totalCost
                if score > bestScore {
                    bestScore = score
                    best = (goal, plan)
                }
            }
            return best
        }
    }

    /// The plan that carries out `composite` when execution reaches it in
    /// `state`, or `nil` if its sub-actions cannot reach its sub-goal. This is
    /// a plan over the composite's own `subActions(in:)`, towards
    /// `subGoal(from:)`.
    ///
    /// Use this for lazy refinement: plan the top level with the composite as
    /// an ordinary action, then call `refine` on each composite when the
    /// agent arrives at it, so the sub-plan starts from the real world.
    public func refine<Composite: GOAPCompositeAction>(
        _ composite: Composite,
        from state: State
    ) -> GOAPPlan<Composite.SubAction>? where Composite.State == State {
        plan(
            from: state,
            goal: composite.subGoal(from: state),
            actionsFor: { composite.subActions(in: $0) }
        )
    }

    /// Plans over `tasks` and expands every sub-planner in the result, all the
    /// way down, before returning.
    ///
    /// Each level is planned with its sub-planners as ordinary actions, using
    /// their declared preconditions, effects and cost. The steps are then
    /// walked in the state the agent would actually be in: a sub-planner is
    /// expanded from that state towards `subGoal(from:)`, and the state its
    /// sub-plan reaches carries on to the next step. A level is rejected with
    /// `.inconsistent` if that state breaks the next step's preconditions or
    /// the level's goal. Nothing is replanned automatically, so the result is
    /// deterministic; for worlds that change as the agent acts, plan the top
    /// level and use `refine` as execution reaches each sub-planner.
    ///
    /// `maxDepth` is the deepest level an expansion may reach; the top level
    /// is 0, so `maxDepth: 0` allows no expansion at all.
    public func planHierarchically<Primitive: GOAPAction>(
        from start: State,
        goal: State.Conditions,
        tasks: [GOAPTask<Primitive>],
        maxDepth: Int = 16
    ) -> Result<GOAPHierarchicalPlan<Primitive>, GOAPHierarchyError>
    where Primitive.State == State {
        planLevel(
            from: start,
            goal: goal,
            tasks: tasks,
            owner: nil,
            depth: 0,
            maxDepth: maxDepth
        )
    }

    /// Plans one level of a hierarchy and expands its sub-planners. `owner` is
    /// the sub-planner this level belongs to, or `nil` at the top.
    private func planLevel<Primitive: GOAPAction>(
        from start: State,
        goal: State.Conditions,
        tasks: [GOAPTask<Primitive>],
        owner: String?,
        depth: Int,
        maxDepth: Int
    ) -> Result<GOAPHierarchicalPlan<Primitive>, GOAPHierarchyError>
    where Primitive.State == State {
        guard let levelPlan = plan(from: start, goal: goal, actions: tasks) else {
            if let owner {
                return .failure(.refinementFailed(subPlanner: owner, depth: depth))
            }
            return .failure(.noPlan)
        }

        var steps: [GOAPHierarchicalPlan<Primitive>.Step] = []
        var states: [State] = [start]
        var actual = start
        var lastExpanded = ""

        for task in levelPlan.actions {
            guard actual.satisfies(task.preconditions) else {
                return .failure(.inconsistent(after: lastExpanded, depth: depth))
            }
            switch task {
            case .primitive(let action):
                actual = actual.applying(action.effects)
                steps.append(.primitive(action))
            case .subPlanner(let subPlanner):
                guard depth + 1 <= maxDepth else {
                    return .failure(.depthExceeded(subPlanner: subPlanner.name))
                }
                let result = planLevel(
                    from: actual,
                    goal: subPlanner.subGoal(from: actual),
                    tasks: subPlanner.subActions(in: actual),
                    owner: subPlanner.name,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
                switch result {
                case .success(let subPlan):
                    actual = subPlan.states[subPlan.states.count - 1]
                    steps.append(.subPlan(subPlanner, subPlan))
                    lastExpanded = subPlanner.name
                case .failure(let error):
                    return .failure(error)
                }
            }
            states.append(actual)
        }

        guard actual.satisfies(goal) else {
            return .failure(.inconsistent(after: lastExpanded, depth: depth))
        }
        return .success(GOAPHierarchicalPlan(steps: steps, states: states))
    }

    private func reconstruct<Action: GOAPAction>(
        target: State,
        cameFrom: [State: (predecessor: State, action: Action)]
    ) -> (actions: [Action], states: [State]) where Action.State == State {
        var actions: [Action] = []
        var states: [State] = [target]
        var node = target
        while let prev = cameFrom[node] {
            actions.append(prev.action)
            states.append(prev.predecessor)
            node = prev.predecessor
        }
        return (actions.reversed(), states.reversed())
    }
}
