/// A value held by a fact in a `RichWorldState`.
public enum StateValue: Hashable {
    case bool(Bool)
    case integer(Int)
    case real(Double)
    case text(String)

    /// Numeric view of this value, if it has one.
    public var numeric: Double? {
        switch self {
        case .integer(let i): return Double(i)
        case .real(let d):    return d
        case .bool, .text:    return nil
        }
    }
}

/// A test against a single fact in a `RichWorldState`.
public enum StateCondition: Hashable {
    case equals(StateValue)
    case notEquals(StateValue)
    case greaterThan(Double)
    case greaterThanOrEqual(Double)
    case lessThan(Double)
    case lessThanOrEqual(Double)

    /// Whether `value` matches this condition.
    public func matches(_ value: StateValue) -> Bool {
        switch self {
        case .equals(let target):    return value == target
        case .notEquals(let target): return value != target
        case .greaterThan(let t):
            guard let n = value.numeric else { return false }
            return n > t
        case .greaterThanOrEqual(let t):
            guard let n = value.numeric else { return false }
            return n >= t
        case .lessThan(let t):
            guard let n = value.numeric else { return false }
            return n < t
        case .lessThanOrEqual(let t):
            guard let n = value.numeric else { return false }
            return n <= t
        }
    }
}

/// A change to apply to a single fact in a `RichWorldState`.
public enum StateEffect: Hashable {
    /// Replace the fact's value.
    case set(StateValue)
    /// Add a delta to a numeric fact. If the fact is missing or non-numeric,
    /// the result is the delta as a `.real`.
    case add(Double)
    /// Subtract a delta from a numeric fact. Same fallback as `.add`.
    case subtract(Double)
}

/// A flexible world state mapping fact names to typed values.
///
/// Use this when your world has numeric quantities (health, ammo, distance) or
/// when the set of facts changes at runtime. For pure boolean worlds with a
/// fixed schema, `BooleanWorldState` is faster.
public struct RichWorldState: WorldState {
    public typealias Conditions = [String: StateCondition]
    public typealias Effects = [String: StateEffect]

    public var values: [String: StateValue]

    public init(_ values: [String: StateValue] = [:]) {
        self.values = values
    }

    public func satisfies(_ conditions: [String: StateCondition]) -> Bool {
        for (key, condition) in conditions {
            guard let value = values[key], condition.matches(value) else {
                return false
            }
        }
        return true
    }

    public func applying(_ effects: [String: StateEffect]) -> RichWorldState {
        var next = values
        for (key, effect) in effects {
            switch effect {
            case .set(let v):
                next[key] = v
            case .add(let delta):
                next[key] = Self.combine(next[key], delta: delta)
            case .subtract(let delta):
                next[key] = Self.combine(next[key], delta: -delta)
            }
        }
        return RichWorldState(next)
    }

    public func heuristicDistance(to conditions: [String: StateCondition]) -> Int {
        var unsatisfied = 0
        for (key, condition) in conditions {
            if let value = values[key], condition.matches(value) { continue }
            unsatisfied += 1
        }
        return unsatisfied
    }

    /// Adds `delta` to a fact's numeric value, preserving `.integer` if the
    /// existing value was an integer and the delta is a whole number.
    private static func combine(_ current: StateValue?, delta: Double) -> StateValue {
        switch current {
        case .integer(let i):
            if delta.rounded() == delta {
                return .integer(i + Int(delta))
            }
            return .real(Double(i) + delta)
        case .real(let d):
            return .real(d + delta)
        case nil, .bool, .text:
            if delta.rounded() == delta {
                return .integer(Int(delta))
            }
            return .real(delta)
        }
    }
}

// MARK: - Convenience constructors

extension StateValue: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .integer(value) }
    public init(floatLiteral value: Double) { self = .real(value) }
    public init(stringLiteral value: String) { self = .text(value) }
}
