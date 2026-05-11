/// A bitmask-backed world state with up to 64 boolean facts.
///
/// Each fact is a single bit indexed `0..<64`. `bits` stores the value of every
/// fact; `mask` records which bits the value carries information about. Bits
/// outside `mask` are "don't care" — useful for partial conditions and partial
/// effects. A fully-defined state has `mask` set on every relevant bit.
///
/// The type maintains the invariant `bits & ~mask == 0`: a bit cannot be
/// "true" if it's outside the mask. Direct construction sanitizes the inputs
/// to preserve this; otherwise satisfaction checks could be fooled by phantom
/// bits with no semantic value.
///
/// Use this state type when speed matters and the world's facts are all
/// boolean. All comparisons and updates run in O(1) on a single 64-bit word.
public struct BooleanWorldState: WorldState, Sendable {
    public typealias Conditions = BooleanWorldState
    public typealias Effects = BooleanWorldState

    /// Bit values for the represented facts. Bit `i` is the value of fact `i`.
    public var bits: UInt64
    /// Which bits carry meaningful information. Bits outside `mask` are "don't
    /// care" for satisfaction and "no effect" for application.
    public var mask: UInt64

    public init(bits: UInt64 = 0, mask: UInt64 = 0) {
        // Enforce invariant: bits set outside mask are meaningless and would
        // make `satisfies` produce wrong answers, so we drop them on the way in.
        self.bits = bits & mask
        self.mask = mask
    }

    /// Sets fact `index` to `value`, marking it as cared-about.
    public mutating func set(_ index: Int, to value: Bool) {
        precondition((0..<64).contains(index), "fact index must be in 0..<64")
        let bit = UInt64(1) << index
        mask |= bit
        if value { bits |= bit } else { bits &= ~bit }
    }

    /// Clears the bit at `index` so it becomes "don't care".
    public mutating func clear(_ index: Int) {
        precondition((0..<64).contains(index), "fact index must be in 0..<64")
        let bit = UInt64(1) << index
        mask &= ~bit
        bits &= ~bit
    }

    /// Returns the value of fact `index`, or `nil` if it's "don't care".
    public func get(_ index: Int) -> Bool? {
        precondition((0..<64).contains(index), "fact index must be in 0..<64")
        let bit = UInt64(1) << index
        guard (mask & bit) != 0 else { return nil }
        return (bits & bit) != 0
    }

    /// Builds a state from a list of `(index, value)` pairs. Bits not in the
    /// list are left "don't care". For closed-world semantics where every
    /// unspecified bit means `false`, set `mask = .max` directly on the result.
    public static func facts(_ pairs: [(Int, Bool)]) -> BooleanWorldState {
        var s = BooleanWorldState()
        for (i, v) in pairs { s.set(i, to: v) }
        return s
    }

    public func satisfies(_ conditions: BooleanWorldState) -> Bool {
        let care = conditions.mask
        return (bits & care) == (conditions.bits & care)
    }

    public func applying(_ effects: BooleanWorldState) -> BooleanWorldState {
        let care = effects.mask
        let newBits = (bits & ~care) | (effects.bits & care)
        let newMask = mask | care
        return BooleanWorldState(bits: newBits, mask: newMask)
    }

    public func heuristicDistance(to conditions: BooleanWorldState) -> Int {
        let care = conditions.mask
        let diff = (bits ^ conditions.bits) & care
        return diff.nonzeroBitCount
    }
}

// MARK: - Type-safe fact enums

/// Convenience overloads that accept any `RawRepresentable` whose `RawValue`
/// is `Int`. This lets you define facts as an enum and avoid magic indices:
///
/// ```swift
/// enum Fact: Int { case hasGun, gunLoaded, enemyDead }
/// var s = BooleanWorldState.facts([(Fact.hasGun, true), (.gunLoaded, false)])
/// s.set(.enemyDead, to: false)
/// s.get(.hasGun)        // → Optional(true)
/// ```
extension BooleanWorldState {
    public static func facts<F: RawRepresentable>(_ pairs: [(F, Bool)]) -> BooleanWorldState
    where F.RawValue == Int {
        facts(pairs.map { ($0.0.rawValue, $0.1) })
    }

    public mutating func set<F: RawRepresentable>(_ fact: F, to value: Bool)
    where F.RawValue == Int {
        set(fact.rawValue, to: value)
    }

    public mutating func clear<F: RawRepresentable>(_ fact: F)
    where F.RawValue == Int {
        clear(fact.rawValue)
    }

    public func get<F: RawRepresentable>(_ fact: F) -> Bool?
    where F.RawValue == Int {
        get(fact.rawValue)
    }
}
