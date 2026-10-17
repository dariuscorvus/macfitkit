import Foundation
import Testing
import MacFitKitCore
@testable import MacFitKitPlatform

private struct InstallFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacFitKitInstallerTests-" + UUID().uuidString)
    var payloads: URL { root.appendingPathComponent("payloads") }
    var applications: URL { root.appendingPathComponent("Applications") }
    func create(_ tool: ToolID, identifier: String? = nil) throws {
        let contents = payloads.appendingPathComponent(tool.name + ".app/Contents")
        let executable = contents.appendingPathComponent("MacOS/" + tool.name)
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plist = ["CFBundleIdentifier": identifier ?? tool.bundleIdentifier, "CFBundleExecutable": tool.name,
                     "CFBundlePackageType": "APPL", "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }
    func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func installsEveryToolAndNeverOverwrites() async throws {
    let fixture = InstallFixture(); defer { fixture.clean() }
    let installer = ToolInstaller(payloadDirectory: fixture.payloads, applicationsDirectory: fixture.applications, verifySignature: { _ in })
    for tool in ToolID.allCases {
        try fixture.create(tool)
        let installed = try await installer.install(tool, systemMajor: 26)
        #expect(Bundle(url: installed)?.bundleIdentifier == tool.bundleIdentifier)
        let marker = installed.appendingPathComponent("keep.txt")
        try Data("preserve".utf8).write(to: marker)
        await #expect(throws: (any Error).self) { try await installer.install(tool, systemMajor: 26) }
        #expect(try String(contentsOf: marker, encoding: .utf8) == "preserve")
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.applications.path).count == 4)
}

@Test func rejectsUnsupportedSystemAndInvalidPayload() async throws {
    let fixture = InstallFixture(); defer { fixture.clean() }
    let installer = ToolInstaller(payloadDirectory: fixture.payloads, applicationsDirectory: fixture.applications, verifySignature: { _ in })
    try fixture.create(.liveDesktop)
    await #expect(throws: InstallError.self) { try await installer.install(.liveDesktop, systemMajor: 14) }
    try fixture.create(.dockPreview, identifier: "wrong.app")
    await #expect(throws: InstallError.self) { try await installer.install(.dockPreview, systemMajor: 26) }
    await #expect(throws: InstallError.self) { try await installer.install(.focusFrame, systemMajor: 26) }
    #expect(!FileManager.default.fileExists(atPath: fixture.applications.path))
}

@Test func failedStagedValidationCleansUp() async throws {
    let fixture = InstallFixture(); defer { fixture.clean() }
    try fixture.create(.focusFrame)
    let installer = ToolInstaller(payloadDirectory: fixture.payloads, applicationsDirectory: fixture.applications, verifySignature: { url in
        if url.path.contains(".MacFitKit-install-") { throw InstallError("Copy rejected") }
    })
    await #expect(throws: InstallError.self) { try await installer.install(.focusFrame, systemMajor: 26) }
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.applications.path).isEmpty)
}

@Test func validatesRealBundledSignaturesAndRejectsTampering() async throws {
    guard let path = ProcessInfo.processInfo.environment["MACFITKIT_INSTALL_TEST_PAYLOADS"] else { return }
    let fixture = InstallFixture(); defer { fixture.clean() }
    let payloads = URL(fileURLWithPath: path)
    let installer = ToolInstaller(payloadDirectory: payloads, applicationsDirectory: fixture.applications)
    for tool in ToolID.allCases {
        let installed = try await installer.install(tool, systemMajor: 26)
        #expect(Bundle(url: installed)?.bundleIdentifier == tool.bundleIdentifier)
    }
    // A valid identifier alone is insufficient: modified signed content must be rejected.
    try FileManager.default.createDirectory(at: fixture.payloads, withIntermediateDirectories: true)
    let tampered = fixture.payloads.appendingPathComponent("FocusFrame.app")
    try FileManager.default.copyItem(at: payloads.appendingPathComponent("FocusFrame.app"), to: tampered)
    let executable = try #require(Bundle(url: tampered)?.executableURL)
    let handle = try FileHandle(forWritingTo: executable)
    try handle.seekToEnd(); try handle.write(contentsOf: Data("tampered".utf8)); try handle.close()
    let rejectedRoot = fixture.root.appendingPathComponent("Rejected")
    let rejected = ToolInstaller(payloadDirectory: fixture.payloads, applicationsDirectory: rejectedRoot)
    await #expect(throws: InstallError.self) { try await rejected.install(.focusFrame, systemMajor: 26) }
    #expect(!FileManager.default.fileExists(atPath: rejectedRoot.path))
}
