/// An action the planner can sequence into a plan.
///
/// An action is enabled when its `preconditions` are satisfied, and changes
/// the world according to its `effects`. `cost` is the weight A* uses to
/// minimize total plan cost. Costs must be non-negative; using cost ≥ 1 keeps
/// the standard "unsatisfied facts" heuristic admissible in the simplest case.
public protocol GOAPAction: Sendable {
    associatedtype State: WorldState

    var name: String { get }
    var cost: Int { get }
    var preconditions: State.Conditions { get }
    var effects: State.Effects { get }
}

/// A concrete `GOAPAction` value type. Use this when you don't need to attach
/// per-action behaviour beyond the planning data — domain code can wire up
/// execution by switching on `name`.
public struct BasicAction<State: WorldState>: GOAPAction, Sendable {
    public let name: String
    public let cost: Int
    public let preconditions: State.Conditions
    public let effects: State.Effects

    public init(
        name: String,
        cost: Int = 1,
        preconditions: State.Conditions,
        effects: State.Effects
    ) {
        self.name = name
        self.cost = cost
        self.preconditions = preconditions
        self.effects = effects
    }
}
