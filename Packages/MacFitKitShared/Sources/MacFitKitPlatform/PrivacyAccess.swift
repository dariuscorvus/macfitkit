import AppKit
@preconcurrency import ApplicationServices
import ScreenCaptureKit
import ServiceManagement
import Observation

@MainActor
public enum PrivacyAccess {
    public static var accessibilityGranted: Bool { AXIsProcessTrusted() }
    public static var screenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }
    public static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openSettings("Privacy_Accessibility")
    }
    public static func requestScreenRecording() async throws {
        _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
    }
    public static func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}

@MainActor @Observable
public final class LoginService {
    public private(set) var enabled = false
    public private(set) var needsApproval = false
    public private(set) var message = ""
    public init() { refresh() }
    public func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }
    public func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            message = ""
        } catch { message = error.localizedDescription }
        refresh()
    }
    public func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
