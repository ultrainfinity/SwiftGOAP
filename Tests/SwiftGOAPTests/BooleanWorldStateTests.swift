import XCTest
@testable import SwiftGOAP

final class BooleanWorldStateTests: XCTestCase {
    func testSetGet() {
        var s = BooleanWorldState()
        s.set(0, to: true)
        s.set(3, to: false)
        XCTAssertEqual(s.get(0), true)
        XCTAssertEqual(s.get(3), false)
        XCTAssertNil(s.get(5))
    }

    func testClear() {
        var s = BooleanWorldState()
        s.set(2, to: true)
        XCTAssertEqual(s.get(2), true)
        s.clear(2)
        XCTAssertNil(s.get(2))
    }

    func testFactsConvenience() {
        let s = BooleanWorldState.facts([(0, true), (1, false), (2, true)])
        XCTAssertEqual(s.get(0), true)
        XCTAssertEqual(s.get(1), false)
        XCTAssertEqual(s.get(2), true)
        XCTAssertNil(s.get(3))
    }

    func testSatisfiesEmptyConditions() {
        let s = BooleanWorldState.facts([(0, true)])
        let cond = BooleanWorldState()
        XCTAssertTrue(s.satisfies(cond))
    }

    func testSatisfiesMatching() {
        let s = BooleanWorldState.facts([(0, true), (1, true), (2, false)])
        let cond = BooleanWorldState.facts([(0, true), (2, false)])
        XCTAssertTrue(s.satisfies(cond))
    }

    func testSatisfiesMismatch() {
        let s = BooleanWorldState.facts([(0, true)])
        let cond = BooleanWorldState.facts([(0, false)])
        XCTAssertFalse(s.satisfies(cond))
    }

    func testSatisfiesIgnoresDontCareBits() {
        let s = BooleanWorldState.facts([(0, true), (5, true)])
        let cond = BooleanWorldState.facts([(0, true)])
        XCTAssertTrue(s.satisfies(cond), "bit 5 is don't-care for the condition")
    }

    func testApplyingEffectsChangesOnlyMaskedBits() {
        var s = BooleanWorldState.facts([(0, true), (1, true)])
        let effects = BooleanWorldState.facts([(0, false)])
        s = s.applying(effects)
        XCTAssertEqual(s.get(0), false)
        XCTAssertEqual(s.get(1), true, "bit 1 should be untouched")
    }

    func testApplyingMergesMasks() {
        let s = BooleanWorldState.facts([(0, true)])
        let effects = BooleanWorldState.facts([(5, true)])
        let next = s.applying(effects)
        XCTAssertEqual(next.get(0), true)
        XCTAssertEqual(next.get(5), true)
    }

    func testHeuristicDistance() {
        let s = BooleanWorldState.facts([(0, false), (1, false), (2, false)])
        let cond = BooleanWorldState.facts([(0, true), (1, true), (2, false)])
        XCTAssertEqual(s.heuristicDistance(to: cond), 2)
    }

    func testHeuristicZeroWhenSatisfied() {
        let s = BooleanWorldState.facts([(0, true), (1, true)])
        let cond = BooleanWorldState.facts([(0, true)])
        XCTAssertEqual(s.heuristicDistance(to: cond), 0)
    }

    // MARK: - Invariant: bits & ~mask == 0

    func testRawConstructorClampsBitsToMask() {
        let s = BooleanWorldState(bits: 0xFF, mask: 0x0F)
        XCTAssertEqual(s.bits, 0x0F, "bits outside mask must be cleared on construction")
        XCTAssertEqual(s.mask, 0x0F)
    }

    func testRawConstructorPreventsPhantomBitSatisfaction() {
        // Without the invariant, a state with bits=0xFF, mask=0x0F could be
        // tricked into satisfying a condition asking for bit 4 = true, even
        // though bit 4 is semantically "don't care" in that state.
        let phantom = BooleanWorldState(bits: 0xFF, mask: 0x0F)
        let cond = BooleanWorldState.facts([(4, true)])
        XCTAssertFalse(phantom.satisfies(cond), "phantom bits must not satisfy real conditions")
    }
}
