//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing
@testable import SCCLib
import SwiftParser
import SwiftSyntax

private let defaultSwiftUIContainers: Set<String> = Set(Configuration.default.swiftuiContainers)

private func analyzeComplexity(
    in source: String,
    filePath: String = "test.swift",
    swiftUIAware: Bool = false,
    swiftUIContainers: Set<String> = defaultSwiftUIContainers
) -> [FunctionComplexity] {
    let sourceFile = Parser.parse(source: source)
    let converter = SourceLocationConverter(fileName: filePath, tree: sourceFile)
    let visitor = CognitiveComplexityVisitor(
        converter: converter,
        filePath: filePath,
        swiftUIAware: swiftUIAware,
        swiftUIContainers: swiftUIContainers
    )
    visitor.walk(sourceFile)
    return visitor.results
}

private func fixturesURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
}

private func analyzeFixture(
    _ name: String,
    swiftUIAware: Bool = false,
    swiftUIContainers: Set<String> = defaultSwiftUIContainers
) throws -> [FunctionComplexity] {
    let url = fixturesURL().appendingPathComponent(name)
    let source = try String(contentsOf: url)
    return analyzeComplexity(
        in: source,
        filePath: name,
        swiftUIAware: swiftUIAware,
        swiftUIContainers: swiftUIContainers
    )
}

// MARK: - White Paper Validation

@Test func sumOfPrimesScores7() throws {
    let results = try analyzeFixture("sumOfPrimes.swift")
    let fn = results.first { $0.name == "sumOfPrimes" }!
    #expect(fn.complexity == 7)
}

@Test func getWordsScores1() throws {
    let results = try analyzeFixture("getWords.swift")
    let fn = results.first { $0.name == "getWords" }!
    #expect(fn.complexity == 1)
}

@Test func myMethodScores9() throws {
    let results = try analyzeFixture("myMethod.swift")
    let fn = results.first { $0.name == "myMethod" }!
    #expect(fn.complexity == 9)
}

@Test func overriddenSymbolFromScores19() throws {
    let results = try analyzeFixture("overriddenSymbolFrom.swift")
    let fn = results.first { $0.name == "overriddenSymbolFrom" }!
    #expect(fn.complexity == 19)
}

// MARK: - Basic Fixture

@Test func basicFixtureScores8() throws {
    // if(+1) + for(+2,n=1) + if(+3,n=2) + else if(+1) + else(+1) = 8
    let results = try analyzeFixture("basic.swift")
    let fn = results.first { $0.name == "example" }!
    #expect(fn.complexity == 8)
}

// MARK: - Individual Structural Increments

@Test func ifScores1AtNesting0() {
    let source = """
    func f() {
        if true { }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func forScores1AtNesting0() {
    let source = """
    func f() {
        for _ in 0..<1 { }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func whileScores1AtNesting0() {
    let source = """
    func f() {
        while false { }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func repeatWhileScores1AtNesting0() {
    let source = """
    func f() {
        repeat { } while false
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func switchScores1AtNesting0() {
    let source = """
    func f() {
        switch 0 { case 0: break; default: break }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func guardScores1AtNesting0() {
    let source = """
    func f() {
        guard true else { return }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func catchScores1AtNesting0() {
    let source = """
    func f() {
        do {
        } catch {
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func ternaryScores1AtNesting0() {
    let source = """
    func f() -> Int {
        return true ? 1 : 0
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

// MARK: - Nesting Penalty

@Test func nestedIfScoresWithNestingPenalty() {
    let source = """
    func f() {
        if true {           // +1 (nesting=0)
            if true { }     // +2 (nesting=1)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func deepNesting() {
    let source = """
    func f() {
        if true {                // +1 (nesting=0)
            for _ in 0..<1 {     // +2 (nesting=1)
                while false {    // +3 (nesting=2)
                }
            }
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 6)
}

// MARK: - Hybrid Increments (else if / else)

@Test func elseIfGetsPlus1NoPenalty() {
    let source = """
    func f() {
        if true {               // +1
        } else if true {        // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func elseGetsPlus1NoPenalty() {
    let source = """
    func f() {
        if true {               // +1
        } else {                // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func ifElseIfElseChain() {
    let source = """
    func f() {
        if true {               // +1
        } else if true {        // +1
        } else if true {        // +1
        } else {                // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 4)
}

@Test func nestedInsideElseIfGetsCorrectNesting() {
    // The else-if itself doesn't bump nesting, but parent if does.
    // So a construct inside else-if sees nesting=1 (from the if).
    let source = """
    func f() {
        if true {               // +1 (nesting=0)
        } else if true {        // +1 (hybrid)
            if true { }         // +2 (nesting=1, from parent if)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 4)
}

@Test func nestedInsideElseGetsCorrectNesting() {
    let source = """
    func f() {
        if true {               // +1 (nesting=0)
        } else {                // +1 (hybrid)
            if true { }         // +2 (nesting=1, from parent if)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 4)
}

// MARK: - Logical Operators

@Test func singleLogicalOperatorScores1() {
    let source = """
    func f() {
        if a && b { }          // +1 (if) + +1 (&&) = 2
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func sameOperatorSequenceScores1() {
    let source = """
    func f() {
        if a && b && c { }    // +1 (if) + +1 (&&) = 2
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func operatorSwitchScoresExtra() {
    let source = """
    func f() {
        if a && b || c { }    // +1 (if) + +1 (&&) + +1 (||) = 3
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func parenthesizedLogicalOperators() {
    let source = """
    func f() {
        if a && (b || c) { }  // +1 (if) + +1 (&&) + +1 (||) = 3
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func complexLogicalExpression() {
    // a && b && c || d || e && f
    // && sequence: +1
    // switch to ||: +1
    // switch to &&: +1
    // Total logical: 3, plus if: +1 = 4
    let source = """
    func f() {
        if a && b && c || d || e && f { }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 4)
}

// MARK: - Labeled Break/Continue

@Test func labeledBreakScores1() {
    let source = """
    func f() {
        OUTER: for _ in 0..<1 {     // +1
            break OUTER              // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func labeledContinueScores1() {
    let source = """
    func f() {
        OUTER: for _ in 0..<1 {     // +1
            continue OUTER           // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func unlabeledBreakAndContinueScore0() {
    let source = """
    func f() {
        for _ in 0..<1 {     // +1
            break
            continue
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

// MARK: - Recursion

@Test func directRecursionScores1() {
    let source = """
    func factorial(_ n: Int) -> Int {
        if n <= 1 {              // +1
            return 1
        }
        return n * factorial(n - 1)  // +1 (recursion)
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func selfRecursionDetected() {
    let source = """
    func foo() {
        self.foo()               // +1 (recursion)
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

// MARK: - Closures and Nested Functions

@Test func closureIncreasesNestingOnly() {
    let source = """
    func f() {
        let c = { () -> Void in
            if true { }          // +2 (if, nesting=1 from closure)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func nestedFunctionIncreasesNestingOnly() {
    let source = """
    func outer() {
        func inner() {
            if true { }          // +2 (if, nesting=1 from nested func)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    // outer scores 0 (inner is a separate function), inner scores 2
    let outer = results.first { $0.name == "outer" }!
    let inner = results.first { $0.name == "inner" }!
    #expect(outer.complexity == 0)
    #expect(inner.complexity == 2)
}

// MARK: - No-Increment Constructs

@Test func tryDoesNotIncrement() {
    let source = """
    func f() throws {
        try something()
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 0)
}

@Test func deferDoesNotIncrement() {
    let source = """
    func f() {
        defer { }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 0)
}

@Test func returnDoesNotIncrement() {
    let source = """
    func f() -> Int {
        return 42
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 0)
}

@Test func nilCoalescingDoesNotIncrement() {
    let source = """
    func f() -> Int {
        let x: Int? = nil
        return x ?? 0
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 0)
}

@Test func methodDeclarationDoesNotIncrement() {
    let source = """
    func f() { }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 0)
}

// MARK: - Edge Cases

@Test func emptyFunctionScores0() {
    let source = """
    func f() { }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 0)
}

@Test func noFunctionsReturnsEmpty() {
    let source = """
    let x = 42
    """
    let results = analyzeComplexity(in: source)
    #expect(results.isEmpty)
}

@Test func multipleFunctionsEachScoredSeparately() {
    let source = """
    func a() {
        if true { }   // +1
    }
    func b() {
        if true {      // +1
            if true { } // +2
        }
    }
    """
    let results = analyzeComplexity(in: source)
    let fnA = results.first { $0.name == "a" }!
    let fnB = results.first { $0.name == "b" }!
    #expect(fnA.complexity == 1)
    #expect(fnB.complexity == 3)
}

@Test func initializerIsAnalyzed() {
    let source = """
    struct S {
        init() {
            if true { }   // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    let fn = results.first { $0.name == "init" }!
    #expect(fn.complexity == 1)
}

@Test func multipleCatchClauses() {
    let source = """
    func f() {
        do {
        } catch is TypeError {     // +1
        } catch is ValueError {    // +1
        } catch {                  // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

// MARK: - SwiftUI-Aware Mode

@Test func swiftuiFixtureScores7() throws {
    // if(+1) + else(+1) + ForEach(+2, nesting=1 from if) + if(+3, nesting=2) = 7
    let results = try analyzeFixture("swiftui_view.swift", swiftUIAware: true)
    let body = results.first { $0.name == "body" }!
    #expect(body.complexity == 7)
}

@Test func deepLayoutNestingNoControlFlowScores0() {
    let source = """
    struct V: View {
        var body: some View {
            NavigationStack {
                VStack {
                    HStack {
                        ZStack {
                            Text("deep")
                        }
                    }
                }
            }
        }
    }
    """
    let results = analyzeComplexity(in: source, swiftUIAware: true)
    let body = results.first { $0.name == "body" }!
    #expect(body.complexity == 0)
}

@Test func ifInsideVStackScores1() {
    let source = """
    struct V: View {
        var body: some View {
            VStack {
                if condition {
                    Text("a")
                }
            }
        }
    }
    """
    let results = analyzeComplexity(in: source, swiftUIAware: true)
    let body = results.first { $0.name == "body" }!
    #expect(body.complexity == 1)
}

@Test func forEachCountsAsLoopWithNesting() {
    let source = """
    struct V: View {
        var body: some View {
            ForEach(items) { item in
                if item.active { }
            }
        }
    }
    """
    let results = analyzeComplexity(in: source, swiftUIAware: true)
    let body = results.first { $0.name == "body" }!
    // ForEach: +1, if: +1 + nesting=1 = +2 => total 3
    #expect(body.complexity == 3)
}

@Test func viewModifierSheetSuppressesNesting() {
    let source = """
    struct V: View {
        var body: some View {
            Text("hi")
                .sheet(isPresented: $show) {
                    if condition { }
                }
        }
    }
    """
    let results = analyzeComplexity(in: source, swiftUIAware: true)
    let body = results.first { $0.name == "body" }!
    #expect(body.complexity == 1)
}

@Test func vstackWithArgumentsSuppressesNesting() {
    let source = """
    struct V: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if condition { }
            }
        }
    }
    """
    let results = analyzeComplexity(in: source, swiftUIAware: true)
    let body = results.first { $0.name == "body" }!
    #expect(body.complexity == 1)
}

@Test func nonSwiftUIUnaffectedByFlag() {
    // Regular closures still increment nesting even with swiftUIAware on
    let source = """
    func f() {
        let c = { () -> Void in
            if true { }
        }
    }
    """
    let withFlag = analyzeComplexity(in: source, swiftUIAware: true)
    let withoutFlag = analyzeComplexity(in: source, swiftUIAware: false)
    #expect(withFlag[0].complexity == 2)
    #expect(withoutFlag[0].complexity == 2)
}

@Test func swiftuiAwareFlagOffProducesHigherScore() {
    // Same view code but wrapped in a function so it's analyzed without swiftUI-aware mode
    let source = """
    func makeView() {
        let _ = NavigationStack {
            VStack {
                if condition {
                    Text("Empty")
                } else {
                    List {
                        ForEach(items) { item in
                            HStack {
                                if item.isUrgent {
                                    Image(systemName: "exclamationmark")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    """
    let withFlag = analyzeComplexity(in: source, swiftUIAware: true)
    let withoutFlag = analyzeComplexity(in: source, swiftUIAware: false)
    let scoreWith = withFlag.first { $0.name == "makeView" }!.complexity
    let scoreWithout = withoutFlag.first { $0.name == "makeView" }!.complexity
    // Without SwiftUI-aware, closures add nesting, so score should be higher
    #expect(scoreWithout > scoreWith)
}

@Test func bodyPropertyTreatedAsFunctionBoundary() {
    let source = """
    struct V: View {
        var body: some View {
            if condition { }
        }
    }
    """
    let results = analyzeComplexity(in: source, swiftUIAware: true)
    let body = results.first { $0.name == "body" }
    #expect(body != nil)
    #expect(body?.complexity == 1)
}

@Test func existingWhitePaperTestsUnchangedWithSwiftUIFlag() throws {
    let sumOfPrimes = try analyzeFixture("sumOfPrimes.swift", swiftUIAware: true)
    #expect(sumOfPrimes.first { $0.name == "sumOfPrimes" }!.complexity == 7)

    let getWords = try analyzeFixture("getWords.swift", swiftUIAware: true)
    #expect(getWords.first { $0.name == "getWords" }!.complexity == 1)

    let myMethod = try analyzeFixture("myMethod.swift", swiftUIAware: true)
    #expect(myMethod.first { $0.name == "myMethod" }!.complexity == 9)

    let overridden = try analyzeFixture("overriddenSymbolFrom.swift", swiftUIAware: true)
    #expect(overridden.first { $0.name == "overriddenSymbolFrom" }!.complexity == 19)
}

// MARK: - Conditional Compilation

@Test func poundIfScores1() {
    let source = """
    func f() {
        #if DEBUG
        let x = 1
        #endif
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func poundIfElseScores2() {
    let source = """
    func f() {
        #if DEBUG
        let x = 1
        #else
        let x = 2
        #endif
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func poundIfElseifElseScores3() {
    let source = """
    func f() {
        #if os(macOS)
        let x = 1
        #elseif os(iOS)
        let x = 2
        #else
        let x = 3
        #endif
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func poundIfNestedInsideIfGetsNestingPenalty() {
    let source = """
    func f() {
        if true {             // +1 (nesting=0)
            #if DEBUG         // +2 (nesting=1)
            let x = 1
            #endif
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func ifNestedInsidePoundIfGetsNestingPenalty() {
    let source = """
    func f() {
        #if DEBUG             // +1 (nesting=0)
        if true { }           // +2 (nesting=1)
        #endif
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func nestedPoundIfGetsNestingPenalty() {
    let source = """
    func f() {
        #if DEBUG             // +1 (nesting=0)
            #if os(macOS)     // +2 (nesting=1)
            let x = 1
            #endif
        #endif
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}

@Test func poundIfAtFileScopeDoesNotScore() {
    let source = """
    #if DEBUG
    let x = 1
    #endif
    """
    let results = analyzeComplexity(in: source)
    #expect(results.isEmpty)
}

// MARK: - Phase 8 Edge Cases

@Test func autoclosureDoesNotIncrement() {
    let source = """
    func f(_ condition: @autoclosure () -> Bool) {
        if condition() { }   // +1 (if only)
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func whereClauseOnForDoesNotAddExtra() {
    let source = """
    func f() {
        for x in [1, 2, 3] where x > 0 { }  // +1 (for only)
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func ifCaseLetCountsAsNormalIf() {
    let source = """
    func f() {
        let opt: Int? = 1
        if case .some(let x) = opt { }  // +1
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func switchWithAssociatedValuesScores1() {
    let source = """
    func f() {
        enum R { case success(Int); case failure(Error) }
        let r = R.success(1)
        switch r {                           // +1
        case .success(let val): _ = val
        case .failure(let err): _ = err
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func asyncLetDoesNotIncrement() {
    let source = """
    func f() async {
        async let x = g()
        _ = await x
    }
    func g() async -> Int { 1 }
    """
    let results = analyzeComplexity(in: source)
    let fn = results.first { $0.name == "f" }!
    #expect(fn.complexity == 0)
}

@Test func withCheckedContinuationClosureIncrementsNesting() {
    let source = """
    func f() async {
        await withCheckedContinuation { continuation in
            if true { }   // +2 (if, nesting=1 from closure)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    let fn = results.first { $0.name == "f" }!
    #expect(fn.complexity == 2)
}

@Test func customResultBuilderFollowsClosureRules() {
    let source = """
    func f() {
        MyBuilder.build {
            if true { }   // +2 (if, nesting=1 from closure)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 2)
}

@Test func stringInterpolationTernaryCounts() {
    let source = """
    func f() -> String {
        let x = 1
        return "value is \\(x > 0 ? "positive" : "negative")"  // +1 (ternary)
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func deferWithIfInsideNoExtraNesting() {
    let source = """
    func f() {
        defer {
            if true { }   // +1 (defer body is CodeBlockSyntax, not closure)
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 1)
}

@Test func multipleCatchWithPatterns() {
    let source = """
    func f() throws {
        do {
            try something()
        } catch is TypeError {           // +1
        } catch let error as ValueError { // +1
        } catch {                         // +1
        }
    }
    """
    let results = analyzeComplexity(in: source)
    #expect(results[0].complexity == 3)
}
