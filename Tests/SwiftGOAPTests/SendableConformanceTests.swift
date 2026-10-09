import XCTest
@testable import SwiftGOAP

/// Sendable conformance is enforced at compile time. The body of this test
/// exists so the file participates in the build — if any public type loses
/// its Sendable conformance, this file stops compiling and the test target
/// fails to build.
final class SendableConformanceTests: XCTestCase {
    func testPublicTypesAreSendable() {
        requireSendable(BooleanWorldState.self)
        requireSendable(RichWorldState.self)
        requireSendable(StateValue.self)
        requireSendable(StateCondition.self)
        requireSendable(StateEffect.self)
        requireSendable(GOAPGoal<BooleanWorldState>.self)
        requireSendable(GOAPGoal<RichWorldState>.self)
        requireSendable(GOAPPlanner<BooleanWorldState>.self)
        requireSendable(GOAPPlanner<RichWorldState>.self)
        requireSendable(BasicAction<BooleanWorldState>.self)
        requireSendable(BasicAction<RichWorldState>.self)
        requireSendable(GOAPPlan<BasicAction<BooleanWorldState>>.self)
        requireSendable(GOAPPlan<BasicAction<RichWorldState>>.self)
        requireSendable(GOAPSubPlanner<BasicAction<BooleanWorldState>>.self)
        requireSendable(GOAPSubPlanner<BasicAction<RichWorldState>>.self)
        requireSendable(GOAPTask<BasicAction<BooleanWorldState>>.self)
        requireSendable(GOAPTask<BasicAction<RichWorldState>>.self)
        requireSendable(GOAPHierarchicalPlan<BasicAction<BooleanWorldState>>.self)
        requireSendable(GOAPHierarchicalPlan<BasicAction<RichWorldState>>.self)
        requireSendable(GOAPHierarchyError.self)
        requireSendable(PriorityQueue<Int>.self)
    }

    private func requireSendable<T: Sendable>(_: T.Type) {}
}
