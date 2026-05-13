/// Rule the planner uses to pick one goal out of many.
///
/// Used by the multi-goal `plan(from:goals:actions:selectingBy:)` overload.
public enum GoalSelectionStrategy: Sendable {
    /// Try goals in descending `priority` and return the first that has a
    /// plan. Stops at the first success — only computes the plans it needs.
    case priority

    /// Compute plans for every goal and return the one maximising
    /// `priority - plan.totalCost`. A cheap low-priority goal can beat an
    /// expensive high-priority one. Costs `O(goals)` planner invocations.
    case maxUtility
}
