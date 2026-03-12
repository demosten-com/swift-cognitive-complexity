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

@Test func repositoryRootInNonGitDirThrows() {
    let tmpDir = NSTemporaryDirectory() + "scc-git-test-\(UUID().uuidString)"
    try! FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let git = GitHelper(workingDirectory: tmpDir)
    #expect(throws: GitHelperError.self) {
        try git.repositoryRoot()
    }
}

@Test func fileContentReturnsNilForMissingFile() throws {
    let tmpDir = NSTemporaryDirectory() + "scc-git-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    // Init a git repo with a commit
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["init"]
    process.currentDirectoryURL = URL(fileURLWithPath: tmpDir)
    try process.run()
    process.waitUntilExit()

    // Configure git user for commit
    let configName = Process()
    configName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    configName.arguments = ["config", "user.email", "test@test.com"]
    configName.currentDirectoryURL = URL(fileURLWithPath: tmpDir)
    try configName.run()
    configName.waitUntilExit()

    let configEmail = Process()
    configEmail.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    configEmail.arguments = ["config", "user.name", "Test"]
    configEmail.currentDirectoryURL = URL(fileURLWithPath: tmpDir)
    try configEmail.run()
    configEmail.waitUntilExit()

    // Create and commit a file
    try "hello".write(toFile: tmpDir + "/existing.txt", atomically: true, encoding: .utf8)
    let add = Process()
    add.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    add.arguments = ["add", "."]
    add.currentDirectoryURL = URL(fileURLWithPath: tmpDir)
    try add.run()
    add.waitUntilExit()

    let commit = Process()
    commit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    commit.arguments = ["commit", "-m", "initial"]
    commit.currentDirectoryURL = URL(fileURLWithPath: tmpDir)
    try commit.run()
    commit.waitUntilExit()

    let git = GitHelper(workingDirectory: tmpDir)
    let content = try git.fileContent(at: "nonexistent.swift", ref: "HEAD")
    #expect(content == nil)
}

@Test func repositoryRootReturnsCorrectPath() throws {
    let tmpDir = NSTemporaryDirectory() + "scc-git-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["init"]
    process.currentDirectoryURL = URL(fileURLWithPath: tmpDir)
    try process.run()
    process.waitUntilExit()

    let git = GitHelper(workingDirectory: tmpDir)
    let root = try git.repositoryRoot()

    // Normalize both paths for comparison (resolve symlinks)
    let expectedPath = (tmpDir as NSString).resolvingSymlinksInPath
    let actualPath = (root as NSString).resolvingSymlinksInPath
    #expect(actualPath == expectedPath)
}
