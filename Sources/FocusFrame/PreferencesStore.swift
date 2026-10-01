import AppKit
import FocusFrameCore

@MainActor
final class PreferencesStore {
    var onChange: (() -> Void)?
    private let defaults: UserDefaults
    var value: Configuration {
        didSet {
            if let data = try? JSONEncoder().encode(value.normalized) { defaults.set(data, forKey: "configuration.v1") }
            onChange?()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "configuration.v1"),
           let stored = try? JSONDecoder().decode(Configuration.self, from: data) {
            value = stored.normalized
        } else {
            var migrated = Configuration()
            if defaults.object(forKey: "borderWidth") != nil {
                migrated.appearance.width = Double(defaults.integer(forKey: "borderWidth"))
            }
            let oldColors: [NSColor] = [.systemOrange, .systemBlue, .systemGreen, .systemPink]
            let index = defaults.integer(forKey: "borderColor")
            if oldColors.indices.contains(index), let color = oldColors[index].usingColorSpace(.sRGB) {
                migrated.appearance.red = color.redComponent
                migrated.appearance.green = color.greenComponent
                migrated.appearance.blue = color.blueComponent
            }
            value = migrated.normalized
        }
    }
}

extension Appearance {
    var color: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity) }
}
