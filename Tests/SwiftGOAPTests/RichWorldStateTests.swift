import XCTest
@testable import SwiftGOAP

final class RichWorldStateTests: XCTestCase {
    func testEqualityCondition() {
        let s = RichWorldState(["hasKey": true])
        XCTAssertTrue(s.satisfies(["hasKey": .equals(true)]))
        XCTAssertFalse(s.satisfies(["hasKey": .equals(false)]))
    }

    func testMissingFactDoesNotSatisfy() {
        let s = RichWorldState([:])
        XCTAssertFalse(s.satisfies(["hasKey": .equals(true)]))
    }

    func testNumericComparisons() {
        let s = RichWorldState(["health": 50])
        XCTAssertTrue(s.satisfies(["health": .greaterThan(40)]))
        XCTAssertTrue(s.satisfies(["health": .greaterThanOrEqual(50)]))
        XCTAssertFalse(s.satisfies(["health": .greaterThan(50)]))
        XCTAssertTrue(s.satisfies(["health": .lessThanOrEqual(50)]))
        XCTAssertFalse(s.satisfies(["health": .lessThan(50)]))
    }

    func testStringEquality() {
        let s = RichWorldState(["location": "kitchen"])
        XCTAssertTrue(s.satisfies(["location": .equals("kitchen")]))
        XCTAssertFalse(s.satisfies(["location": .equals("garden")]))
    }

    func testNotEquals() {
        let s = RichWorldState(["state": "alive"])
        XCTAssertTrue(s.satisfies(["state": .notEquals("dead")]))
        XCTAssertFalse(s.satisfies(["state": .notEquals("alive")]))
    }

    func testApplyingSet() {
        let s = RichWorldState(["health": 50])
        let next = s.applying(["health": .set(.integer(100))])
        XCTAssertEqual(next.values["health"], .integer(100))
    }

    func testApplyingAddPreservesInteger() {
        let s = RichWorldState(["ammo": 5])
        let next = s.applying(["ammo": .add(3)])
        XCTAssertEqual(next.values["ammo"], .integer(8))
    }

    func testApplyingAddPromotesToReal() {
        let s = RichWorldState(["x": 5])
        let next = s.applying(["x": .add(0.5)])
        XCTAssertEqual(next.values["x"], .real(5.5))
    }

    func testApplyingSubtract() {
        let s = RichWorldState(["ammo": 10])
        let next = s.applying(["ammo": .subtract(3)])
        XCTAssertEqual(next.values["ammo"], .integer(7))
    }

    func testApplyingMultipleEffects() {
        let s = RichWorldState(["a": 1, "b": 2])
        let next = s.applying([
            "a": .add(10),
            "b": .set(.integer(99)),
            "c": .set(.bool(true))
        ])
        XCTAssertEqual(next.values["a"], .integer(11))
        XCTAssertEqual(next.values["b"], .integer(99))
        XCTAssertEqual(next.values["c"], .bool(true))
    }

    func testHeuristicCountsUnsatisfied() {
        let s = RichWorldState(["a": 1, "b": 2, "c": 3])
        let conds: [String: StateCondition] = [
            "a": .equals(.integer(1)),     // satisfied
            "b": .equals(.integer(99)),    // not satisfied
            "c": .greaterThan(100)         // not satisfied
        ]
        XCTAssertEqual(s.heuristicDistance(to: conds), 2)
    }

    func testStateValueLiteralsCompile() {
        let s = RichWorldState([
            "flag": true,
            "count": 5,
            "ratio": 0.5,
            "name": "spam"
        ])
        XCTAssertEqual(s.values["flag"], .bool(true))
        XCTAssertEqual(s.values["count"], .integer(5))
        XCTAssertEqual(s.values["ratio"], .real(0.5))
        XCTAssertEqual(s.values["name"], .text("spam"))
    }

    // MARK: - Numeric effects must be applied to numeric facts only

    func testAddRequiresNumericFact() {
        // Positive case: integer fact, .add stays valid.
        let s1 = RichWorldState(["x": 5])
        XCTAssertEqual(s1.applying(["x": .add(3)]).values["x"], .integer(8))

        // Positive case: .set first, .add second works (the documented pattern
        // for initializing-then-incrementing).
        let s2 = RichWorldState([:])
            .applying(["x": .set(.integer(0))])
            .applying(["x": .add(7)])
        XCTAssertEqual(s2.values["x"], .integer(7))

        // Negative cases trigger preconditionFailure and aren't testable in
        // XCTest without subprocess tricks. The contract: .add/.subtract on a
        // missing key or on a .bool/.text fact traps. Documented in
        // StateEffect's docstring.
    }
}
