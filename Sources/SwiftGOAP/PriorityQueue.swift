/// A simple binary min-heap priority queue.
///
/// `enqueue` is O(log n), `dequeue` is O(log n), `peek` is O(1). Stable order
/// is not preserved between elements with equal priority.
public struct PriorityQueue<Element> {
    private var heap: [(priority: Int, element: Element)] = []

    public init() {}

    public var isEmpty: Bool { heap.isEmpty }
    public var count: Int { heap.count }

    public mutating func enqueue(_ element: Element, priority: Int) {
        heap.append((priority, element))
        siftUp(from: heap.count - 1)
    }

    public mutating func dequeue() -> Element? {
        guard !heap.isEmpty else { return nil }
        heap.swapAt(0, heap.count - 1)
        let last = heap.removeLast()
        if !heap.isEmpty {
            siftDown(from: 0)
        }
        return last.element
    }

    public func peek() -> Element? {
        heap.first?.element
    }

    private mutating func siftUp(from index: Int) {
        var i = index
        while i > 0 {
            let parent = (i - 1) / 2
            if heap[i].priority < heap[parent].priority {
                heap.swapAt(i, parent)
                i = parent
            } else {
                return
            }
        }
    }

    private mutating func siftDown(from index: Int) {
        var i = index
        let n = heap.count
        while true {
            let left = 2 * i + 1
            let right = 2 * i + 2
            var smallest = i
            if left < n, heap[left].priority < heap[smallest].priority {
                smallest = left
            }
            if right < n, heap[right].priority < heap[smallest].priority {
                smallest = right
            }
            if smallest == i { return }
            heap.swapAt(i, smallest)
            i = smallest
        }
    }
}
