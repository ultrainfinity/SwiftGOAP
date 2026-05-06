/// A goal the planner tries to satisfy.
///
/// `priority` is for callers that pick between several goals — the planner
/// itself only consumes the conditions. A higher priority typically means
/// "prefer this goal first if a plan exists for it."
public struct GOAPGoal<State: WorldState> {
    public let name: String
    public let conditions: State.Conditions
    public let priority: Int

    public init(name: String, conditions: State.Conditions, priority: Int = 1) {
        self.name = name
        self.conditions = conditions
        self.priority = priority
    }
}
