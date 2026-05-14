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
