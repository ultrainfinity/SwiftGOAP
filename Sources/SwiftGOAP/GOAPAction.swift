/// An action the planner can sequence into a plan.
///
/// An action is enabled when its `preconditions` are satisfied, and changes
/// the world according to its `effects`. `cost` is the weight A* uses to
/// minimize total plan cost. Costs must be non-negative; using cost ≥ 1 keeps
/// the standard "unsatisfied facts" heuristic admissible in the simplest case.
///
/// For dynamic cost — vary by distance, urgency, world conditions — override
/// `cost(in:)`. The default implementation returns the static `cost`.
public protocol GOAPAction: Sendable {
    associatedtype State: WorldState

    var name: String { get }
    var cost: Int { get }
    var preconditions: State.Conditions { get }
    var effects: State.Effects { get }

    /// The cost of this action when evaluated in `state`. Defaults to `cost`.
    /// Override to make cost depend on the state (e.g. "travel to X" should
    /// cost more when X is far).
    func cost(in state: State) -> Int
}

extension GOAPAction {
    public func cost(in state: State) -> Int { cost }
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

/// An action that is also a planner over actions of its own.
///
/// At the level that contains it, a composite action is an ordinary action:
/// the planner sequences it by its `preconditions`, `effects` and `cost`.
/// When execution reaches it, it is expanded — a sub-plan is searched over
/// `subActions(in:)` from the state the agent is actually in, aiming at
/// `subGoal(from:)`. Sub-actions may themselves be composite, to any depth.
///
/// The declared `effects` are a promise, not a recipe: the sub-plan is free to
/// reach the goal by any route, and the state it ends in replaces the state
/// the declaration predicted.
public protocol GOAPCompositeAction: GOAPAction {
    associatedtype SubAction: GOAPAction where SubAction.State == State

    /// Actions available to the sub-plan when expanding from `state`.
    func subActions(in state: State) -> [SubAction]

    /// Goal of the sub-plan when the composite starts in `state`. Defaults to
    /// the composite's `effects`, pinned to the values they produce in `state`.
    func subGoal(from state: State) -> State.Conditions
}

extension GOAPCompositeAction {
    public func subGoal(from state: State) -> State.Conditions {
        state.applying(effects).conditions(pinning: effects)
    }
}

/// A concrete `GOAPCompositeAction` whose sub-actions are fixed. Its children
/// are `GOAPTask`s, so a sub-planner can hold primitives and further
/// sub-planners side by side.
public struct GOAPSubPlanner<Primitive: GOAPAction>: GOAPCompositeAction, Sendable {
    public typealias State = Primitive.State
    public typealias SubAction = GOAPTask<Primitive>

    public let name: String
    public let cost: Int
    public let preconditions: State.Conditions
    public let effects: State.Effects
    /// The actions the sub-plan chooses from, whatever state it starts in.
    public let children: [GOAPTask<Primitive>]
    private let customSubGoal: (@Sendable (State) -> State.Conditions)?

    /// Creates a sub-planner. Pass `subGoal` to compute the sub-plan's goal
    /// from the starting state; otherwise the goal is the pinned `effects`.
    public init(
        name: String,
        cost: Int = 1,
        preconditions: State.Conditions,
        effects: State.Effects,
        children: [GOAPTask<Primitive>],
        subGoal: (@Sendable (State) -> State.Conditions)? = nil
    ) {
        self.name = name
        self.cost = cost
        self.preconditions = preconditions
        self.effects = effects
        self.children = children
        self.customSubGoal = subGoal
    }

    public func subActions(in state: State) -> [GOAPTask<Primitive>] { children }

    public func subGoal(from state: State) -> State.Conditions {
        if let customSubGoal { return customSubGoal(state) }
        return state.applying(effects).conditions(pinning: effects)
    }
}

/// A node of a hierarchical action set: either an executable `Primitive` or a
/// `GOAPSubPlanner` that expands into more tasks. Every task is a `GOAPAction`,
/// so primitives and sub-planners can be planned over together.
public enum GOAPTask<Primitive: GOAPAction>: GOAPAction, Sendable {
    public typealias State = Primitive.State

    case primitive(Primitive)
    case subPlanner(GOAPSubPlanner<Primitive>)

    public var name: String {
        switch self {
        case .primitive(let action):  return action.name
        case .subPlanner(let planner): return planner.name
        }
    }

    public var cost: Int {
        switch self {
        case .primitive(let action):  return action.cost
        case .subPlanner(let planner): return planner.cost
        }
    }

    public var preconditions: State.Conditions {
        switch self {
        case .primitive(let action):  return action.preconditions
        case .subPlanner(let planner): return planner.preconditions
        }
    }

    public var effects: State.Effects {
        switch self {
        case .primitive(let action):  return action.effects
        case .subPlanner(let planner): return planner.effects
        }
    }

    public func cost(in state: State) -> Int {
        switch self {
        case .primitive(let action):  return action.cost(in: state)
        case .subPlanner(let planner): return planner.cost(in: state)
        }
    }
}
