/// A plan returned by `GOAPPlanner`.
///
/// Carries the action sequence together with the trajectory of intermediate
/// states (`states[0]` is the start; `states.last` satisfies the goal). Total
/// cost is computed lazily from the actions.
///
/// An empty plan (`actions.isEmpty == true`) means the start state already
/// satisfied the goal — no action is needed.
public struct GOAPPlan<Action: GOAPAction>: Sendable {
    /// The ordered actions to execute, from first to last.
    public let actions: [Action]

    /// The sequence of states the agent moves through. `states[0]` is the
    /// start; `states[i+1] == states[i].applying(actions[i].effects)`. Length
    /// equals `actions.count + 1`. For an empty plan, contains the start state.
    public let states: [Action.State]

    /// Sum of the action costs, evaluated in the state each action would run
    /// in. For actions that override `cost(in:)` this respects context; for
    /// plain actions it matches the sum of static `cost` values.
    public var totalCost: Int {
        var total = 0
        for (i, action) in actions.enumerated() {
            total += action.cost(in: states[i])
        }
        return total
    }

    /// Number of actions in the plan.
    public var count: Int { actions.count }

    /// Whether the plan contains no actions (start already satisfied the goal).
    public var isEmpty: Bool { actions.isEmpty }

    public init(actions: [Action], states: [Action.State]) {
        precondition(
            states.count == actions.count + 1,
            "GOAPPlan: states.count must equal actions.count + 1"
        )
        self.actions = actions
        self.states = states
    }
}

/// A plan whose steps may be sub-plans, returned by
/// `GOAPPlanner.planHierarchically`.
///
/// Each step is either a primitive action or a `GOAPSubPlanner` together with
/// the plan it was expanded into. Sub-plans are plans in their own right, so
/// the structure mirrors the hierarchy of the task set. `flattened` collapses
/// it into the executable sequence.
public struct GOAPHierarchicalPlan<Primitive: GOAPAction>: Sendable {
    /// One step of a plan level.
    public indirect enum Step: Sendable {
        /// An executable action.
        case primitive(Primitive)
        /// A sub-planner and the plan it expanded into.
        case subPlan(GOAPSubPlanner<Primitive>, GOAPHierarchicalPlan<Primitive>)
    }

    /// Steps at this level, in execution order.
    public let steps: [Step]

    /// Actual states at this level: `states[0]` is the start, `states[i + 1]`
    /// the state after `steps[i]` (after a sub-plan — the state its primitives
    /// actually reach). Length equals `steps.count + 1`.
    public let states: [Primitive.State]

    /// The executable primitives in order, with their trajectory. `totalCost`
    /// sums the costs of the primitives, not the costs declared by the
    /// sub-planners that were expanded into them.
    public var flattened: GOAPPlan<Primitive> {
        var actions: [Primitive] = []
        var trajectory: [Primitive.State] = [states[0]]
        for (i, step) in steps.enumerated() {
            switch step {
            case .primitive(let action):
                actions.append(action)
                trajectory.append(states[i + 1])
            case .subPlan(_, let plan):
                let inner = plan.flattened
                actions.append(contentsOf: inner.actions)
                trajectory.append(contentsOf: inner.states.dropFirst())
            }
        }
        return GOAPPlan(actions: actions, states: trajectory)
    }

    public init(steps: [Step], states: [Primitive.State]) {
        precondition(
            states.count == steps.count + 1,
            "GOAPHierarchicalPlan: states.count must equal steps.count + 1"
        )
        self.steps = steps
        self.states = states
    }
}

/// Why `GOAPPlanner.planHierarchically` could not produce a plan.
public enum GOAPHierarchyError: Error, Equatable, Sendable {
    /// The top level has no plan to the goal.
    case noPlan
    /// No sub-plan exists for `subPlanner` from the state it was expanded in.
    /// `depth` is the level of the sub-plan; the top level is 0.
    case refinementFailed(subPlanner: String, depth: Int)
    /// After `after` was expanded, the state it actually reached no longer
    /// satisfies the next step's preconditions, or the level's goal. `depth`
    /// is the level at which that was detected.
    case inconsistent(after: String, depth: Int)
    /// Expanding `subPlanner` would nest deeper than the allowed `maxDepth`.
    case depthExceeded(subPlanner: String)
}
