/// A world state usable by the GOAP planner.
///
/// Conforming types describe the facts that make up an agent's view of the
/// world. The planner searches over states by checking action preconditions,
/// applying effects, and measuring distance to a goal.
///
/// `Conditions` describes a partial test against a state (a goal or an action's
/// precondition). `Effects` describes a change to apply (an action's effect).
/// They are associated types so each conforming state type can choose the
/// representation that fits best — bitmasks for performance, dictionaries for
/// flexibility.
public protocol WorldState: Hashable, Sendable {
    /// A partial description of facts to test against a state.
    associatedtype Conditions: Sendable
    /// A description of how an action changes a state.
    associatedtype Effects: Sendable

    /// Whether this state satisfies every fact described by `conditions`.
    func satisfies(_ conditions: Conditions) -> Bool

    /// A new state with `effects` applied. Facts not mentioned by `effects`
    /// are unchanged.
    func applying(_ effects: Effects) -> Self

    /// Conditions that hold exactly when every fact mentioned by `effects` has
    /// the value it has in this state. Facts that `effects` doesn't mention
    /// are unconstrained.
    ///
    /// Call this on the state *after* applying `effects` to turn a change into
    /// an absolute target: a relative effect such as "add 3 to ammo" becomes
    /// "ammo equals the value reached", independent of where it was applied.
    func conditions(pinning effects: Effects) -> Conditions

    /// An admissible heuristic estimate of the cost from this state to any
    /// state that satisfies `conditions`. Must never overestimate, or A* will
    /// no longer be guaranteed optimal.
    func heuristicDistance(to conditions: Conditions) -> Int
}
