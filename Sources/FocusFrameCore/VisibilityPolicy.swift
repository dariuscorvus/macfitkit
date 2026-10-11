public enum VisibilityDecision: String, Sendable {
    case show = "Rahmen sichtbar"
    case paused = "Rahmen pausiert"
    case permissionRequired = "Bedienungshilfen fehlen"
    case excluded = "App ausgeschlossen"
    case fullScreen = "Vollbild: Rahmen ausgeblendet"
    case noWindow = "Kein verfügbares Fenster"
}

public enum VisibilityPolicy {
    public static func decide(enabled: Bool, trusted: Bool, excluded: Bool = false,
                              fullScreen: Bool = false, hideInFullScreen: Bool = false,
                              hasWindow: Bool = true) -> VisibilityDecision {
        if !trusted { return .permissionRequired }
        if !enabled { return .paused }
        if excluded { return .excluded }
        if !hasWindow { return .noWindow }
        if fullScreen && hideInFullScreen { return .fullScreen }
        return .show
    }
}

/// Only Finder desktop targets are excluded; regular and other apps' windows stay visible.
public enum DesktopFocusPolicy {
    public static func isDesktop(isFinder: Bool, role: String, matchingLayers: [Int], desktopIconLevel: Int) -> Bool {
        guard isFinder else { return false }
        if role == "AXScrollArea" { return true }
        // A normal Finder window may have the exact same bounds as the desktop.
        if matchingLayers.contains(where: { $0 >= 0 }) { return false }
        return matchingLayers.contains { $0 <= desktopIconLevel }
    }
}
