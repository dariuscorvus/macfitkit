import Foundation

public struct LiveSettings: Codable, Equatable, Sendable {
    public var version = 1
    public var library: LibraryOptions?
    public var manualPause = false
    public var pauseOnLowPower = true
    public var rotationEnabled = false
    public var rotationMinutes = 15
    public var rotationPaths: [String] = []
    public var selections: [String: String] = [:]
    public var extraRoots: [String] = []
    public var explicitFiles: [String] = []
    public init() {}
    public var normalized: Self {
        var result = self
        result.rotationMinutes = [1,5,15,30,60].contains(rotationMinutes) ? rotationMinutes : 15
        result.rotationPaths = rotationPaths.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        return result
    }
}

public enum SurfaceState: Equatable, Sendable {
    case idle, loading, playing, paused, failed(String)
    public var label: String {
        switch self {
        case .idle: "macOS-Hintergrund"
        case .loading: "Video wird geladen …"
        case .playing: "Wiedergabe läuft"
        case .paused: "Pausiert"
        case .failed(let message): "Fehler: " + message
        }
    }
}

public struct VideoPlaylist: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var paths: [String]
    public init(id: String = UUID().uuidString, name: String, paths: [String] = []) {
        self.id = id; self.name = name; self.paths = paths
    }
}
public struct LibraryOptions: Codable, Equatable, Sendable {
    public var favorites: [String] = []
    public var playlists: [VideoPlaylist] = []
    public var displayPlaylists: [String: String] = [:]
    public var selectedPlaylist = "default"
    public var shuffle = false
    public var pauseOnBattery = false
    public var crossfade = true
    public init() {}
}
public struct ShuffleCycle: Sendable {
    private var remaining: [String] = []
    private var candidates: Set<String> = []
    public init() {}
    public mutating func next(current: String, paths: [String]) -> String? {
        let unique = Array(Set(paths))
        guard unique.count >= 2 else { return nil }
        if candidates != Set(unique) { candidates = Set(unique); remaining = [] }
        if remaining.isEmpty {
            remaining = unique.shuffled()
            if remaining.first == current { remaining.swapAt(0, 1) }
        }
        return remaining.removeFirst()
    }
}
public struct PortableLibrary: Codable, Sendable {
    public var version = 1
    public var favorites: [String]
    public var playlists: [VideoPlaylist]
    public var shuffle: Bool
    public var interval: Int
    public var pauseOnLowPower: Bool
    public var pauseOnBattery: Bool
    public var crossfade: Bool
    public init(favorites: [String], playlists: [VideoPlaylist], shuffle: Bool, interval: Int, pauseOnLowPower: Bool, pauseOnBattery: Bool, crossfade: Bool) {
        self.favorites = favorites; self.playlists = playlists; self.shuffle = shuffle; self.interval = interval
        self.pauseOnLowPower = pauseOnLowPower; self.pauseOnBattery = pauseOnBattery; self.crossfade = crossfade
    }
}
