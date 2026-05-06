import XCTest
@testable import SwiftGOAP

final class PriorityQueueTests: XCTestCase {
    func testEmpty() {
        var q = PriorityQueue<String>()
        XCTAssertTrue(q.isEmpty)
        XCTAssertEqual(q.count, 0)
        XCTAssertNil(q.peek())
        XCTAssertNil(q.dequeue())
    }

    func testEnqueueDequeueSorted() {
        var q = PriorityQueue<String>()
        q.enqueue("c", priority: 3)
        q.enqueue("a", priority: 1)
        q.enqueue("b", priority: 2)

        XCTAssertEqual(q.count, 3)
        XCTAssertEqual(q.dequeue(), "a")
        XCTAssertEqual(q.dequeue(), "b")
        XCTAssertEqual(q.dequeue(), "c")
        XCTAssertNil(q.dequeue())
    }

    func testPeekDoesNotRemove() {
        var q = PriorityQueue<Int>()
        q.enqueue(10, priority: 5)
        q.enqueue(20, priority: 1)
        XCTAssertEqual(q.peek(), 20)
        XCTAssertEqual(q.count, 2)
    }

    func testManyElements() {
        var q = PriorityQueue<Int>()
        let values = [9, 4, 7, 1, 5, 3, 8, 2, 6, 0]
        for v in values { q.enqueue(v, priority: v) }

        var out: [Int] = []
        while let v = q.dequeue() { out.append(v) }
        XCTAssertEqual(out, values.sorted())
    }

    func testDuplicatePriorities() {
        var q = PriorityQueue<String>()
        q.enqueue("a", priority: 1)
        q.enqueue("b", priority: 1)
        q.enqueue("c", priority: 1)
        var seen: Set<String> = []
        while let v = q.dequeue() { seen.insert(v) }
        XCTAssertEqual(seen, ["a", "b", "c"])
    }
}
