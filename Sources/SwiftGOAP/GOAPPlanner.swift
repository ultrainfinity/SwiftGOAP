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
    /// plan exists within `maxNodes` expansions. An empty array means the
    /// start state already satisfies the goal.
    public func plan<Action: GOAPAction>(
        from start: State,
        goal: State.Conditions,
        actions: [Action]
    ) -> [Action]? where Action.State == State {
        if start.satisfies(goal) { return [] }

        var gScore: [State: Int] = [start: 0]
        var cameFrom: [State: (predecessor: State, action: Action)] = [:]

        var frontier = PriorityQueue<State>()
        frontier.enqueue(start, priority: start.heuristicDistance(to: goal))

        var expansions = 0

        while let current = frontier.dequeue() {
            if current.satisfies(goal) {
                return reconstruct(target: current, cameFrom: cameFrom)
            }

            expansions += 1
            if expansions > maxNodes { return nil }

            let currentG = gScore[current] ?? .max

            for action in actions {
                guard current.satisfies(action.preconditions) else { continue }
                precondition(action.cost >= 0, "action '\(action.name)' has negative cost")

                let next = current.applying(action.effects)
                let tentativeG = currentG + action.cost

                if tentativeG < (gScore[next] ?? .max) {
                    gScore[next] = tentativeG
                    cameFrom[next] = (current, action)
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
    ) -> [Action]? where Action.State == State {
        plan(from: start, goal: goal.conditions, actions: actions)
    }

    /// Tries each goal in descending priority order and returns the first
    /// matched goal together with its plan. Use this when an agent has a list
    /// of competing goals and should pursue the highest-priority one that is
    /// currently achievable.
    public func plan<Action: GOAPAction>(
        from start: State,
        goals: [GOAPGoal<State>],
        actions: [Action]
    ) -> (goal: GOAPGoal<State>, plan: [Action])? where Action.State == State {
        let ordered = goals.sorted { $0.priority > $1.priority }
        for goal in ordered {
            if let plan = plan(from: start, goal: goal.conditions, actions: actions) {
                return (goal, plan)
            }
        }
        return nil
    }

    private func reconstruct<Action: GOAPAction>(
        target: State,
        cameFrom: [State: (predecessor: State, action: Action)]
    ) -> [Action] where Action.State == State {
        var path: [Action] = []
        var node = target
        while let prev = cameFrom[node] {
            path.append(prev.action)
            node = prev.predecessor
        }
        return path.reversed()
    }
}
