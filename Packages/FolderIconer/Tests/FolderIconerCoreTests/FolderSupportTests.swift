import AppKit
import Foundation
import Testing
@testable import FolderIconerCore

@Test func resourceForkFromSetIconHoldsAllTenRepresentations() throws {
    let root = temporaryDirectory("Fork"); defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(ResourceFork.setIcon(fixtureRenderer.iconImage(DocumentPackage()), on: root))
    let fork = try #require(ResourceFork.read(folder: root)), data = try #require(ResourceFork.icnsData(fromResourceFork: fork))
    #expect(data.prefix(4) == Data("icns".utf8))
    #expect(Set(icnsTypes(data)).isSuperset(of: ["ic04", "ic05", "ic07", "ic08", "ic09", "ic10", "ic11", "ic12", "ic13", "ic14"]))
    #expect(ResourceFork.icnsData(fromResourceFork: fork.prefix(fork.count / 2)) == nil)
    #expect(ResourceFork.icnsData(fromResourceFork: fork.prefix(10)) == nil)
    #expect(ResourceFork.icnsData(fromResourceFork: Data((0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })) == nil)
    #expect(ResourceFork.icnsData(fromResourceFork: Data()) == nil)
}

@Test func registryRoundTripsAndMissingFileIsEmpty() throws {
    let root = temporaryDirectory("Registry"); defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("Registry.json")
    #expect(try FolderRegistry.load(from: url) == FolderRegistry())
    let entry = RegistryEntry(id: UUID(), folderBookmark: Data([1, 2, 3]), folderPath: "/tmp/x", document: "Documents/x.foldericon",
                              backup: nil, appliedIconSHA256: "abc", appliedAt: Date(timeIntervalSince1970: 1_792_000_000))
    try FolderRegistry(entries: [entry]).save(to: url)
    #expect(try FolderRegistry.load(from: url) == FolderRegistry(entries: [entry]))
    let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    #expect(json["format"] as? Int == 1 && (json["entries"] as? [[String: Any]])?.first?["appliedAt"] as? String == ISO8601DateFormatter().string(from: entry.appliedAt))
}

@Test func gitRootIsFoundFromADirectoryOrAFile() throws {
    let root = temporaryDirectory("Git"); defer { try? FileManager.default.removeItem(at: root) }
    let repo = root.appendingPathComponent("repo"), nested = repo.appendingPathComponent("a/b"), worktree = root.appendingPathComponent("worktree")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
    try Data("gitdir: /elsewhere\n".utf8).write(to: worktree.appendingPathComponent(".git"))
    #expect(GitIgnore.repositoryRoot(containing: nested)?.path == repo.path)
    #expect(GitIgnore.repositoryRoot(containing: repo)?.path == repo.path)
    #expect(GitIgnore.repositoryRoot(containing: worktree)?.path == worktree.path)
    #expect(GitIgnore.repositoryRoot(containing: root) == nil)
}

@Test(arguments: ["Icon?", "Icon[\\r]", "Icon\\r", "/Icon?", "Icon\r\r", "Icon?  "])
func existingIconRuleIsDetected(rule: String) throws {
    let root = temporaryDirectory("Rule"); defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = Data(".DS_Store\n\(rule)\nbuild/\n".utf8); try original.write(to: root.appendingPathComponent(".gitignore"))
    #expect(GitIgnore.ignoresIconFiles(root: root))
    #expect(try GitIgnore.addIconRule(root: root) == false)
    #expect(try Data(contentsOf: root.appendingPathComponent(".gitignore")) == original)
}

@Test(arguments: [nil, "", "build/", "build/\n"])
func iconRuleIsAppendedOnceAndKeepsContent(existing: String?) throws {
    let root = temporaryDirectory("Append"); defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent(".gitignore")
    if let existing { try Data(existing.utf8).write(to: file) }
    #expect(!GitIgnore.ignoresIconFiles(root: root))
    #expect(try GitIgnore.addIconRule(root: root))
    #expect(try GitIgnore.addIconRule(root: root) == false)
    let expected = (existing ?? "").isEmpty ? "Icon?\n" : "build/\nIcon?\n"
    #expect(try String(contentsOf: file, encoding: .utf8) == expected)
}

@Test func applyReportsARepositoryOnlyWhileItLacksTheRule() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let repo = try fixture.folder("repo"); try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
    let folder = try fixture.folder("repo/assets"), applier = try fixture.applier()
    let doc = DocumentPackage()
    #expect(try #require(await applier.apply(doc, to: [folder]).first).get().gitRepository?.path == repo.path)
    try GitIgnore.addIconRule(root: repo)
    #expect(try #require(await applier.apply(doc, to: [folder]).first).get().gitRepository == nil)
}
