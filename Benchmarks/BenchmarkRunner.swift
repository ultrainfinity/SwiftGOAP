import Foundation

/// Minimal benchmark harness. No external dependencies — auto-tunes iteration
/// count to stay above a target measurement window, then reports the best
/// nanoseconds-per-op across several samples.
///
/// Why best-of-N instead of mean: best filters out scheduler noise more
/// reliably than mean on a multi-tenant macOS laptop. Mean and stddev are
/// also reported so unusually noisy runs are visible.
struct BenchmarkRunner {

    struct Result {
        let name: String
        let category: String
        let nsPerOp: Double          // best-of-N median scaled per single op
        let opsPerSec: Double
        let samples: [Double]        // raw ns-per-op per sample, for stddev
        let iterations: Int          // ops per sample after autotuning
    }

    /// Target wall-clock time per sample (so the loop overhead is negligible
    /// vs. the work being timed). 50 ms is comfortable on Apple Silicon.
    static let targetSampleNanoseconds: UInt64 = 50_000_000
    /// Number of samples to collect after autotuning. Reports the median.
    static let sampleCount = 7

    private var results: [Result] = []

    /// Runs `body` enough times to fill the sample window, repeats `sampleCount`
    /// times, records the median.
    mutating func measure(
        _ name: String,
        category: String,
        _ body: () -> Void
    ) {
        // Warm-up + iteration tuning: do a small run, scale up until a single
        // batch crosses the target window.
        var iters = 64
        while true {
            let t0 = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iters { body() }
            let dt = DispatchTime.now().uptimeNanoseconds - t0
            if dt >= Self.targetSampleNanoseconds || iters > 1 << 28 { break }
            // Scale iters by how short we were, plus a 20% safety margin.
            let scale = max(2, Double(Self.targetSampleNanoseconds) / Double(max(dt, 1)) * 1.2)
            iters = Int(Double(iters) * scale)
        }

        var samples: [Double] = []
        for _ in 0..<Self.sampleCount {
            let t0 = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iters { body() }
            let dt = DispatchTime.now().uptimeNanoseconds - t0
            samples.append(Double(dt) / Double(iters))
        }

        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        results.append(Result(
            name: name,
            category: category,
            nsPerOp: median,
            opsPerSec: 1e9 / median,
            samples: samples,
            iterations: iters
        ))
    }

    /// Prints a side-by-side table of paired Boolean vs Rich results within
    /// each category. The shape is opinionated: every benchmark name must
    /// exist in both world-state flavours so we can compute a ratio.
    func printReport() {
        print(banner("SwiftGOAP Benchmark Suite"))
        print("Best of \(Self.sampleCount) samples per benchmark · sample window ≈ \(Self.targetSampleNanoseconds / 1_000_000) ms")
        print("Build: \(buildMode()) · Platform: \(platformDescription())\n")

        // Group by category, then by benchmark name; pair "Boolean"/"Rich".
        let grouped = Dictionary(grouping: results, by: \.category)
        let categoryOrder = ["Primitive ops", "Set membership", "Planning"]
        for cat in categoryOrder where grouped[cat] != nil {
            print(sectionHeader(cat))
            print(tableHeader())
            print(rule())

            // Pair up: Boolean/Rich entries with matching name prefix.
            let bools = grouped[cat]!.filter { $0.name.hasPrefix("Boolean: ") }
            let richs = grouped[cat]!.filter { $0.name.hasPrefix("Rich: ") }

            for b in bools {
                let baseName = String(b.name.dropFirst("Boolean: ".count))
                let r = richs.first { $0.name == "Rich: \(baseName)" }
                printRow(baseName, boolean: b, rich: r)
            }
            print()
        }
    }

    // MARK: - Formatting helpers

    private func printRow(_ name: String, boolean: Result, rich: Result?) {
        let bool = formatNs(boolean.nsPerOp)
        let boolThr = formatThroughput(boolean.opsPerSec)
        let boolStddev = "±" + formatNs(stddev(boolean.samples))

        if let r = rich {
            let richNs = formatNs(r.nsPerOp)
            let richStddev = "±" + formatNs(stddev(r.samples))
            let ratio = r.nsPerOp / boolean.nsPerOp
            let ratioStr = String(format: "%.1fx", ratio)
            print(columns([
                (name, 32, .left),
                (bool, 12, .right),
                (boolStddev, 10, .right),
                (richNs, 12, .right),
                (richStddev, 10, .right),
                (ratioStr, 8, .right),
                (boolThr, 10, .right),
            ]))
        } else {
            print(columns([
                (name, 32, .left),
                (bool, 12, .right),
                (boolStddev, 10, .right),
                ("—", 12, .right),
                ("—", 10, .right),
                ("—", 8, .right),
                (boolThr, 10, .right),
            ]))
        }
    }

    private func tableHeader() -> String {
        columns([
            ("Operation", 32, .left),
            ("Boolean",   12, .right),
            ("stddev",    10, .right),
            ("Rich",      12, .right),
            ("stddev",    10, .right),
            ("ratio",      8, .right),
            ("ops/s (B)", 10, .right),
        ])
    }

    private enum Alignment { case left, right }

    /// Tiny fixed-width column formatter. Swift's String(format: "%s", …) is
    /// unhappy with Swift Strings; this avoids that whole printf surface.
    private func columns(_ cells: [(String, Int, Alignment)]) -> String {
        cells.map { text, width, align in
            // Truncate if too long, otherwise pad.
            if text.count >= width {
                return String(text.prefix(width))
            }
            let pad = String(repeating: " ", count: width - text.count)
            return align == .left ? text + pad : pad + text
        }.joined(separator: "  ")
    }

    private func rule() -> String {
        String(repeating: "─", count: 110)
    }

    private func formatNs(_ ns: Double) -> String {
        if ns < 1_000 { return String(format: "%.0f ns", ns) }
        if ns < 1_000_000 { return String(format: "%.2f µs", ns / 1_000) }
        return String(format: "%.2f ms", ns / 1_000_000)
    }

    private func formatThroughput(_ ops: Double) -> String {
        if ops >= 1_000_000 { return String(format: "%.1fM/s", ops / 1_000_000) }
        if ops >= 1_000 { return String(format: "%.1fK/s", ops / 1_000) }
        return String(format: "%.0f/s", ops)
    }

    private func stddev(_ samples: [Double]) -> Double {
        guard samples.count > 1 else { return 0 }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count - 1)
        // Double has a native .squareRoot() since Swift 4.x; no Foundation import needed.
        return variance.squareRoot()
    }

    private func banner(_ text: String) -> String {
        let rule = String(repeating: "═", count: text.count + 4)
        return "\(rule)\n  \(text)\n\(rule)"
    }

    private func sectionHeader(_ text: String) -> String {
        "\n## \(text)"
    }

    private func buildMode() -> String {
        #if DEBUG
        return "DEBUG (numbers will be 5-10× slower than release)"
        #else
        return "RELEASE"
        #endif
    }

    private func platformDescription() -> String {
        let p = ProcessInfo.processInfo
        return "\(p.operatingSystemVersionString)"
    }
}

