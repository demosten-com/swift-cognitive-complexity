//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import SwiftSyntax

public class CognitiveComplexityVisitor: SyntaxVisitor {
    private let converter: SourceLocationConverter
    private let filePath: String
    private var nestingLevel: Int = 0
    private var functionStack: [FunctionContext] = []
    public private(set) var results: [FunctionComplexity] = []

    /// Tracks nodes that incremented nesting, so visitPost can decrement correctly.
    private var nestingIncrementedNodes: Set<SyntaxIdentifier> = []

    // SwiftUI-aware mode
    private let swiftUIAware: Bool
    private let swiftUIContainers: Set<String>
    /// Closures whose nesting increment should be suppressed (SwiftUI containers).
    private var suppressedClosures: Set<SyntaxIdentifier> = []

    private struct FunctionContext {
        let name: String
        let line: Int
        let column: Int
        var complexity: Int = 0
        var details: [ComplexityIncrement] = []
    }

    public init(
        converter: SourceLocationConverter,
        filePath: String,
        swiftUIAware: Bool = false,
        swiftUIContainers: Set<String> = []
    ) {
        self.converter = converter
        self.filePath = filePath
        self.swiftUIAware = swiftUIAware
        // Store both original and lowercased forms for modifier matching
        var containers = Set<String>()
        for name in swiftUIContainers {
            containers.insert(name)
            containers.insert(name.lowercased())
        }
        self.swiftUIContainers = containers
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Helpers

    private func addIncrement(at node: some SyntaxProtocol, description: String, baseIncrement: Int, includeNesting: Bool) {
        guard !functionStack.isEmpty else { return }
        let location = node.startLocation(converter: converter)
        let total = includeNesting ? baseIncrement + nestingLevel : baseIncrement
        let desc = includeNesting && nestingLevel > 0
            ? "+\(total) (\(description), nesting=\(nestingLevel))"
            : "+\(baseIncrement) (\(description))"
        functionStack[functionStack.count - 1].complexity += total
        functionStack[functionStack.count - 1].details.append(
            ComplexityIncrement(line: location.line, description: desc, increment: total)
        )
    }

    private func incrementNesting(for node: some SyntaxProtocol) {
        nestingLevel += 1
        nestingIncrementedNodes.insert(node.id)
    }

    private func decrementNestingIfNeeded(for node: some SyntaxProtocol) {
        if nestingIncrementedNodes.remove(node.id) != nil {
            nestingLevel -= 1
        }
    }

    private func isElseIf(_ node: IfExprSyntax) -> Bool {
        guard let parent = node.parent else { return false }
        // Check if this IfExprSyntax is inside another IfExprSyntax's elseBody
        if let parentIf = parent.as(IfExprSyntax.self) {
            if case .ifExpr(let elseIfExpr) = parentIf.elseBody, elseIfExpr.id == node.id {
                return true
            }
        }
        return false
    }

    /// Counts logical operator sequence increments from a flat list of SequenceExprSyntax elements.
    /// Returns the total increment for operator sequences.
    private func scoreLogicalOperators(in elements: ExprListSyntax, relativeTo node: some SyntaxProtocol) {
        var lastLogicalOp: String? = nil
        for element in elements {
            guard let binOp = element.as(BinaryOperatorExprSyntax.self) else { continue }
            let op = binOp.operator.text
            guard op == "&&" || op == "||" else {
                // Non-logical operator breaks the sequence
                lastLogicalOp = nil
                continue
            }
            if lastLogicalOp == nil || lastLogicalOp != op {
                // New sequence or switch between operators
                addIncrement(at: binOp, description: op, baseIncrement: 1, includeNesting: false)
                lastLogicalOp = op
            }
            // Same operator continues the sequence — no increment
        }
    }

    // MARK: - Function Boundaries

    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = node.name.startLocation(converter: converter)
        let name = node.name.text
        // Nested function increases nesting but no +1
        if !functionStack.isEmpty {
            incrementNesting(for: node)
        }
        functionStack.append(FunctionContext(name: name, line: location.line, column: location.column))
        return .visitChildren
    }

    override public func visitPost(_ node: FunctionDeclSyntax) {
        guard let ctx = functionStack.popLast() else { return }
        results.append(FunctionComplexity(
            name: ctx.name,
            filePath: filePath,
            line: ctx.line,
            column: ctx.column,
            complexity: ctx.complexity,
            details: ctx.details
        ))
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = node.initKeyword.startLocation(converter: converter)
        if !functionStack.isEmpty {
            incrementNesting(for: node)
        }
        functionStack.append(FunctionContext(name: "init", line: location.line, column: location.column))
        return .visitChildren
    }

    override public func visitPost(_ node: InitializerDeclSyntax) {
        guard let ctx = functionStack.popLast() else { return }
        results.append(FunctionComplexity(
            name: ctx.name,
            filePath: filePath,
            line: ctx.line,
            column: ctx.column,
            complexity: ctx.complexity,
            details: ctx.details
        ))
        decrementNestingIfNeeded(for: node)
    }

    // MARK: - Structural Increments (+1 + nesting)

    override public func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        if isElseIf(node) {
            // Hybrid: +1, no nesting penalty, but DO increase nesting for children
            addIncrement(at: node, description: "else if", baseIncrement: 1, includeNesting: false)
            // Don't increment nesting — parent if already did
        } else {
            // Top-level if: +1 + nesting
            addIncrement(at: node, description: "if", baseIncrement: 1, includeNesting: true)
            incrementNesting(for: node)
        }

        // Check for else (CodeBlockSyntax in elseBody, not another IfExprSyntax)
        if let elseBody = node.elseBody, elseBody.is(CodeBlockSyntax.self) {
            let elseKeyword = node.elseKeyword!
            addIncrement(at: elseKeyword, description: "else", baseIncrement: 1, includeNesting: false)
        }

        return .visitChildren
    }

    override public func visitPost(_ node: IfExprSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "for", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: ForStmtSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "while", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: WhileStmtSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "repeat-while", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: RepeatStmtSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "switch", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: SwitchExprSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "guard", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: GuardStmtSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    override public func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "catch", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: CatchClauseSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    // Ternary in unresolved AST is UnresolvedTernaryExprSyntax inside SequenceExprSyntax
    override public func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind {
        addIncrement(at: node, description: "ternary", baseIncrement: 1, includeNesting: true)
        incrementNesting(for: node)
        return .visitChildren
    }

    override public func visitPost(_ node: UnresolvedTernaryExprSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    // MARK: - Conditional Compilation (#if/#elseif/#else)

    override public func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        switch node.poundKeyword.tokenKind {
        case .poundIf:
            addIncrement(at: node, description: "#if", baseIncrement: 1, includeNesting: true)
            // Increment nesting on the parent IfConfigDeclSyntax so it persists across sibling clauses
            if let parent = node.parent?.as(IfConfigClauseListSyntax.self)?.parent?.as(IfConfigDeclSyntax.self) {
                incrementNesting(for: parent)
            }
        case .poundElseif:
            addIncrement(at: node, description: "#elseif", baseIncrement: 1, includeNesting: false)
        case .poundElse:
            addIncrement(at: node, description: "#else", baseIncrement: 1, includeNesting: false)
        default:
            break
        }
        return .visitChildren
    }

    override public func visitPost(_ node: IfConfigDeclSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    // MARK: - Nesting Only (no +1)

    override public func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        if suppressedClosures.remove(node.id) == nil {
            incrementNesting(for: node)
        }
        return .visitChildren
    }

    override public func visitPost(_ node: ClosureExprSyntax) {
        decrementNestingIfNeeded(for: node)
    }

    // MARK: - Fundamental Increments

    override public func visit(_ node: BreakStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.label != nil {
            addIncrement(at: node, description: "labeled break", baseIncrement: 1, includeNesting: false)
        }
        return .visitChildren
    }

    override public func visit(_ node: ContinueStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.label != nil {
            addIncrement(at: node, description: "labeled continue", baseIncrement: 1, includeNesting: false)
        }
        return .visitChildren
    }

    // MARK: - Logical Operator Sequences
    // In unresolved AST, logical operators appear as BinaryOperatorExprSyntax
    // within a flat SequenceExprSyntax: [expr, op, expr, op, expr, ...]

    override public func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        scoreLogicalOperators(in: node.elements, relativeTo: node)
        return .visitChildren
    }

    // MARK: - SwiftUI-Aware: body property as function boundary

    override public func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard swiftUIAware else { return .visitChildren }
        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  identifier.identifier.text == "body",
                  let typeAnnotation = binding.typeAnnotation,
                  typeAnnotation.type.is(SomeOrAnyTypeSyntax.self),
                  binding.accessorBlock != nil else {
                continue
            }
            let location = identifier.startLocation(converter: converter)
            functionStack.append(FunctionContext(
                name: "body",
                line: location.line,
                column: location.column
            ))
        }
        return .visitChildren
    }

    override public func visitPost(_ node: VariableDeclSyntax) {
        guard swiftUIAware else { return }
        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  identifier.identifier.text == "body",
                  let typeAnnotation = binding.typeAnnotation,
                  typeAnnotation.type.is(SomeOrAnyTypeSyntax.self),
                  binding.accessorBlock != nil else {
                continue
            }
            guard let ctx = functionStack.popLast() else { return }
            results.append(FunctionComplexity(
                name: ctx.name,
                filePath: filePath,
                line: ctx.line,
                column: ctx.column,
                complexity: ctx.complexity,
                details: ctx.details
            ))
        }
    }

    // MARK: - SwiftUI-Aware: Container and ForEach Detection + Recursion

    private func calledName(of node: FunctionCallExprSyntax) -> String? {
        if let declRef = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            return declRef.baseName.text
        }
        if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName.text
        }
        return nil
    }

    private func suppressTrailingClosures(of node: FunctionCallExprSyntax) {
        if let trailing = node.trailingClosure {
            suppressedClosures.insert(trailing.id)
        }
        for additional in node.additionalTrailingClosures {
            suppressedClosures.insert(additional.closure.id)
        }
    }

    override public func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // SwiftUI container detection
        if swiftUIAware, node.trailingClosure != nil {
            if let name = calledName(of: node) {
                if name == "ForEach" {
                    // ForEach is a loop: +1 structural + nesting, but suppress closure nesting
                    addIncrement(at: node, description: "ForEach", baseIncrement: 1, includeNesting: true)
                    incrementNesting(for: node)
                    suppressTrailingClosures(of: node)
                } else if swiftUIContainers.contains(name) {
                    suppressTrailingClosures(of: node)
                }
            }
        }

        // Recursion detection
        guard let currentFunc = functionStack.last else { return .visitChildren }
        let calleeName: String?
        if let declRef = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            calleeName = declRef.baseName.text
        } else if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
                  memberAccess.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self" {
            calleeName = memberAccess.declName.baseName.text
        } else {
            calleeName = nil
        }
        if let name = calleeName, name == currentFunc.name {
            addIncrement(at: node, description: "recursion", baseIncrement: 1, includeNesting: false)
        }
        return .visitChildren
    }

    override public func visitPost(_ node: FunctionCallExprSyntax) {
        decrementNestingIfNeeded(for: node)
    }
}
