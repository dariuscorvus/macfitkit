import Foundation
import Testing
@testable import FolderIconerCore

@Test func pendingTargetsKeepOrderAndSkipFilesPackagesAndDuplicates() throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let a = try fixture.folder("A"), b = try fixture.folder("B"), app = try fixture.folder("Some.app"), file = fixture.root.appendingPathComponent("file.txt")
    try Data().write(to: file)
    var targets = PendingTargets([b, file, app, a, fixture.root.appendingPathComponent("missing")])
    #expect(targets.folders == [b, a])
    targets.add([URL(fileURLWithPath: a.path + "/"), a.appendingPathComponent("..").appendingPathComponent("B")])
    #expect(targets.folders == [b, a])
    targets.remove(b); #expect(targets.folders == [a])
    targets.removeAll(); #expect(targets.isEmpty)
}

@Test func serviceEditsOneRegisteredFolderAndTargetsEverythingElse() throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let a = try fixture.folder("A"), b = try fixture.folder("B"), file = fixture.root.appendingPathComponent("file.txt"), id = UUID()
    try Data().write(to: file)
    let entry: (URL) -> RegistryEntry.ID? = { $0 == a ? id : nil }
    #expect(ServiceRequest(selection: [a], entry: entry) == .edit(id))
    #expect(ServiceRequest(selection: [a, file], entry: entry) == .edit(id))
    #expect(ServiceRequest(selection: [b], entry: entry) == .target([b]))
    #expect(ServiceRequest(selection: [a, b], entry: entry) == .target([a, b]))
    #expect(ServiceRequest(selection: [file], entry: entry) == nil)
    #expect(ServiceRequest(selection: [], entry: entry) == nil)
}

@Test func reapplyingOneFolderLeavesTheOtherCopiesUnchanged() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folders = try ["A", "B", "C"].map(fixture.folder), applier = try fixture.applier()
    let original = package(base: .color, [(.red, { $0.clipToFolder = true })])
    let ids = try await applier.apply(original, to: folders).map { try $0.get().entry }
    let hashes = folders.map(ResourceFork.iconHash)
    var edited = try await applier.document(for: ids[0]); edited.document.layers.removeLast()
    _ = try await applier.apply(edited, to: [folders[0]]).first?.get()
    #expect(try await applier.document(for: ids[0]).document == edited.document)
    for index in 1..<3 { #expect(try await applier.document(for: ids[index]) == original) }
    #expect(ResourceFork.iconHash(folder: folders[0]) != hashes[0])
    #expect(Array(folders.dropFirst().map(ResourceFork.iconHash)) == Array(hashes.dropFirst()))
}
