import AppKit
import Foundation
import Testing
@testable import FolderIconerCore

private func failure(_ result: Result<ApplyResult, ApplyError>) -> ApplyError? { if case .failure(let error) = result { error } else { nil } }

private let document = package(base: .color, [(.red, { $0.clipToFolder = true })])

@Test func applyWritesIconFlagEntryAndDocument() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Plain"), applier = try fixture.applier()
    let result = try #require(await applier.apply(document, to: [folder]).first).get()
    #expect(iconFileExists(folder) && hasCustomIconFlag(folder))
    #expect(icnsTypes(try #require(icns(folder))).count == 10)
    let entry = try #require(await applier.entries().first)
    #expect(entry.id == result.entry && entry.backup == nil && entry.appliedIconSHA256 == ResourceFork.iconHash(folder: folder))
    #expect(try await applier.document(for: entry.id) == document)
    #expect(same(await applier.status(of: entry.id), .applied(folder)))
    #expect(try FolderRegistry.load(from: fixture.storage.registry) == FolderRegistry(entries: await applier.entries()))
}

@Test func restoreWithoutPreviousIconRemovesIconFileAndFlag() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Plain"), applier = try fixture.applier()
    let id = try #require(await applier.apply(document, to: [folder]).first).get().entry
    try await applier.restore(id)
    #expect(!iconFileExists(folder) && !hasCustomIconFlag(folder))
    #expect(await applier.entries().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: fixture.storage.document(id).path))
}

@Test func restoreBringsBackThePreviousCustomIconByteForByte() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Custom"), applier = try fixture.applier()
    #expect(ResourceFork.setIcon(solidIcon(.red), on: folder))
    let originalFork = try #require(ResourceFork.read(folder: folder)), originalIcns = try #require(icns(folder))
    let id = try #require(await applier.apply(document, to: [folder]).first).get().entry
    #expect(icns(folder) != originalIcns)
    #expect(try Data(contentsOf: fixture.storage.backup(id)) == originalFork)
    try await applier.restore(id)
    #expect(icns(folder) == originalIcns && ResourceFork.read(folder: folder) == originalFork && hasCustomIconFlag(folder))
    let color = try #require(customIconColor(folder))
    #expect(abs(color[0] - 255) <= 3 && color[1] <= 3 && color[2] <= 3)
    #expect(!FileManager.default.fileExists(atPath: fixture.storage.backup(id).path))
}

@Test func reapplyKeepsTheFirstBackupAndEntry() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Custom"), applier = try fixture.applier()
    #expect(ResourceFork.setIcon(solidIcon(.red), on: folder))
    let originalIcns = try #require(icns(folder))
    let first = try #require(await applier.apply(document, to: [folder]).first).get().entry
    var second = document; second.document.layers[0].content = .folderBase(FolderBase(style: .color, color: RGBAColor(r: 0, g: 0.5, b: 0)))
    #expect(try #require(await applier.apply(second, to: [folder]).first).get().entry == first)
    #expect(await applier.entries().count == 1)
    #expect(try await applier.document(for: first) == second)
    try await applier.restore(first)
    #expect(icns(folder) == originalIcns)
}

@Test func externalChangeOrRemovalBlocksRestoreUnlessForced() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let changed = try fixture.folder("Changed"), removed = try fixture.folder("Removed"), applier = try fixture.applier()
    let ids = try await applier.apply(document, to: [changed, removed]).map { try $0.get().entry }
    #expect(ResourceFork.setIcon(solidIcon(.white), on: changed))
    try FileManager.default.removeItem(at: ResourceFork.iconFile(in: removed))
    #expect(same(await applier.status(of: ids[0]), .changedExternally(changed)))
    #expect(same(await applier.status(of: ids[1]), .changedExternally(removed)))
    await #expect(throws: ApplyError.changedExternally) { try await applier.restore(ids[0]) }
    #expect(await applier.entries().count == 2)
    try await applier.restore(ids[0], force: true)
    #expect(!iconFileExists(changed) && !hasCustomIconFlag(changed))
}

@Test func renamedFolderIsFoundThroughTheBookmark() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Before"), applier = try fixture.applier()
    let id = try #require(await applier.apply(document, to: [folder]).first).get().entry
    let renamed = fixture.root.appendingPathComponent("After", isDirectory: true)
    try FileManager.default.moveItem(at: folder, to: renamed)
    guard case .applied(let found) = await applier.status(of: id) else { Issue.record("not applied after rename"); return }
    #expect(found.lastPathComponent == "After")
    #expect(await applier.entries().first?.folderPath.hasSuffix("/After") == true)
    // A fresh applier reads the refreshed path from disk.
    #expect(try await fixture.applier().entries().first?.folderPath.hasSuffix("/After") == true)
    try await applier.restore(id)
    #expect(!iconFileExists(renamed) && !hasCustomIconFlag(renamed))
}

@Test func deletedFolderIsUnavailableAndCanOnlyBeRemoved() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Gone"), applier = try fixture.applier()
    let id = try #require(await applier.apply(document, to: [folder]).first).get().entry
    try FileManager.default.removeItem(at: folder)
    #expect(await applier.status(of: id) == .unavailable(lastPath: folder.path))
    await #expect(throws: ApplyError.folderUnavailable) { try await applier.restore(id) }
    try await applier.remove(id)
    #expect(await applier.entries().isEmpty && !FileManager.default.fileExists(atPath: fixture.storage.document(id).path))
}

@Test func threeFoldersGetThreeEntriesAndDocuments() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folders = try ["A", "B", "C"].map(fixture.folder), applier = try fixture.applier()
    let ids = try await applier.apply(document, to: folders).map { try $0.get().entry }
    #expect(Set(ids).count == 3 && folders.allSatisfy(hasCustomIconFlag))
    for id in ids { #expect(try await applier.document(for: id) == document) }
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.storage.root.appendingPathComponent("Documents").path).count == 3)
}

@Test func refusedFoldersLeaveNoTrace() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let locked = try fixture.folder("Locked"), app = try fixture.folder("Some.app"), file = fixture.root.appendingPathComponent("file.txt")
    #expect(ResourceFork.setIcon(solidIcon(.red), on: locked))
    try Data().write(to: file); try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
    let applier = try fixture.applier()
    let results = await applier.apply(document, to: [locked, app, file, fixture.root.appendingPathComponent("missing")])
    #expect(results.map(failure) == [.notWritable, .isPackageOrVolume, .notAFolder, .notAFolder])
    #expect(await applier.entries().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: fixture.storage.root.appendingPathComponent("Backups").path))
}

@Test func failedSetIconRollsBackBackupAndRegistry() async throws {
    let fixture = ApplyFixture(); defer { fixture.clean() }
    let folder = try fixture.folder("Custom")
    #expect(ResourceFork.setIcon(solidIcon(.red), on: folder))
    let originalFork = try #require(ResourceFork.read(folder: folder))
    let failFirst = FailFirstSetIcon(), applier = try fixture.applier(setIcon: { failFirst($0, $1) })
    #expect(await applier.apply(document, to: [folder]).first.flatMap(failure) == .setIconFailed)
    #expect(await applier.entries().isEmpty && ResourceFork.read(folder: folder) == originalFork)
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.storage.root.appendingPathComponent("Backups").path).isEmpty)
}
