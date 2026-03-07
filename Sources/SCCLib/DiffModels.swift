public struct FunctionDelta: Sendable, Equatable {
    public let name: String
    public let line: Int
    public let beforeComplexity: Int?
    public let afterComplexity: Int?
    public let delta: Int

    public init(name: String, line: Int, beforeComplexity: Int?, afterComplexity: Int?, delta: Int) {
        self.name = name
        self.line = line
        self.beforeComplexity = beforeComplexity
        self.afterComplexity = afterComplexity
        self.delta = delta
    }
}

public struct FileDiffReport: Sendable, Equatable {
    public let path: String
    public let beforeComplexity: Int
    public let afterComplexity: Int
    public let delta: Int
    public let functionDeltas: [FunctionDelta]

    public init(path: String, beforeComplexity: Int, afterComplexity: Int, delta: Int, functionDeltas: [FunctionDelta]) {
        self.path = path
        self.beforeComplexity = beforeComplexity
        self.afterComplexity = afterComplexity
        self.delta = delta
        self.functionDeltas = functionDeltas
    }
}

public struct DiffReport: Sendable {
    public let changedFiles: [FileDiffReport]
    public let totalDelta: Int
    public let warningThreshold: Int
    public let errorThreshold: Int
    public let newViolations: [FunctionComplexity]
    public let resolvedViolations: [FunctionComplexity]
    public let elapsedSeconds: Double

    public init(
        changedFiles: [FileDiffReport],
        totalDelta: Int,
        warningThreshold: Int,
        errorThreshold: Int,
        newViolations: [FunctionComplexity],
        resolvedViolations: [FunctionComplexity],
        elapsedSeconds: Double
    ) {
        self.changedFiles = changedFiles
        self.totalDelta = totalDelta
        self.warningThreshold = warningThreshold
        self.errorThreshold = errorThreshold
        self.newViolations = newViolations
        self.resolvedViolations = resolvedViolations
        self.elapsedSeconds = elapsedSeconds
    }
}
