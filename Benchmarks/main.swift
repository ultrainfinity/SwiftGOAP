// Entry point for the SwiftGOAP benchmark suite.
//
// Usage:
//   swift run -c release Benchmarks
//
// Running without `-c release` produces numbers that are 5-10× slower than
// production behaviour — only useful as a smoke test. The runner prints a
// warning when invoked in DEBUG.

var runner = BenchmarkRunner()

runPrimitiveBenchmarks(into: &runner)
runPlanningBenchmarks(into: &runner)

runner.printReport()
