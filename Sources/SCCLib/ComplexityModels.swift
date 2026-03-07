import SwiftSyntax

public struct ComplexityIncrement: Sendable, Equatable {
    public let line: Int
    public let description: String
    public let increment: Int

    public init(line: Int, description: String, increment: Int) {
        self.line = line
        self.description = description
        self.increment = increment
    }
}

public struct FunctionComplexity: Sendable, Equatable {
    public let name: String
    public let filePath: String
    public let line: Int
    public let column: Int
    public let complexity: Int
    public let details: [ComplexityIncrement]

    public init(name: String, filePath: String, line: Int, column: Int, complexity: Int, details: [ComplexityIncrement]) {
        self.name = name
        self.filePath = filePath
        self.line = line
        self.column = column
        self.complexity = complexity
        self.details = details
    }
}
