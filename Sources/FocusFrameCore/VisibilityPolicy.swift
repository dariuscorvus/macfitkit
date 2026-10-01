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
