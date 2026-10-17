import Foundation
import Security
import MacFitKitCore

/// Installs only the payload shipped inside the hub. Existing applications are never replaced.
public actor ToolInstaller {
    private let payloadDirectory: URL
    private let applicationsDirectory: URL
    private let verifySignature: @Sendable (URL) throws -> Void

    public init(payloadDirectory: URL, applicationsDirectory: URL) {
        self.payloadDirectory = payloadDirectory
        self.applicationsDirectory = applicationsDirectory
        self.verifySignature = Self.validateSignature
    }

    // Tests use isolated application roots and fixture signatures.
    init(payloadDirectory: URL, applicationsDirectory: URL,
         verifySignature: @escaping @Sendable (URL) throws -> Void) {
        self.payloadDirectory = payloadDirectory
        self.applicationsDirectory = applicationsDirectory
        self.verifySignature = verifySignature
    }

    public func install(_ tool: ToolID, systemMajor: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) throws -> URL {
        guard systemMajor >= tool.minimumSystemMajor else {
            throw InstallError("\(tool.name) benötigt macOS \(tool.minimumSystemMajor) oder neuer.")
        }
        let manager = FileManager.default
        let source = payloadDirectory.appendingPathComponent(tool.name + ".app", isDirectory: true)
        let destination = applicationsDirectory.appendingPathComponent(tool.name + ".app", isDirectory: true)
        guard !manager.fileExists(atPath: destination.path) else {
            throw InstallError("Unter \(destination.path) ist bereits eine App vorhanden. Sie wurde nicht verändert.")
        }
        try validate(source, tool: tool)
        try manager.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)
        // Stage on the destination volume, verify the copy, then publish with a non-overwriting move.
        let staging = applicationsDirectory.appendingPathComponent(".MacFitKit-install-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }
        let stagedApp = staging.appendingPathComponent(tool.name + ".app", isDirectory: true)
        try manager.copyItem(at: source, to: stagedApp)
        try validate(stagedApp, tool: tool)
        try manager.moveItem(at: stagedApp, to: destination)
        return destination
    }

    private func validate(_ url: URL, tool: ToolID) throws {
        guard let bundle = Bundle(url: url), bundle.bundleIdentifier == tool.bundleIdentifier,
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw InstallError("Das Installationspaket für \(tool.name) fehlt oder ist ungültig. Bitte MacFitKit mit allen Tools erneut laden.")
        }
        try verifySignature(url)
    }

    static func validateSignature(_ url: URL) throws {
        var code: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url as CFURL, [], &code)
        guard created == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate), nil) == errSecSuccess else {
            throw InstallError("Die Signatur des Installationspakets ist ungültig. Die Installation wurde abgebrochen.")
        }
    }
}

public struct InstallError: LocalizedError, Sendable {
    public let errorDescription: String?
    public init(_ description: String) { errorDescription = description }
}
