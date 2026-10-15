import SwiftUI
import MacFitKitCore
import MacFitKitPlatform

public enum KitSpacing { public static let small: CGFloat = 8; public static let medium: CGFloat = 12; public static let group: CGFloat = 16; public static let page: CGFloat = 24 }

public struct SettingsPage: Identifiable, Hashable, Sendable {
    public let id: String; public let title: String; public let symbol: String
    public init(_ id: String, _ title: String, _ symbol: String) { self.id = id; self.title = title; self.symbol = symbol }
    public static let general = Self("general", "Allgemein", "gearshape")
    public static let permissions = Self("permissions", "Berechtigungen", "hand.raised")
    public static let info = Self("info", "Info", "info.circle")
}

public struct SettingsShell<Content: View>: View {
    private let title: String; private let pages: [SettingsPage]; private let content: (String) -> Content
    @State private var selection: String?
    public init(_ title: String, pages: [SettingsPage], @ViewBuilder content: @escaping (String) -> Content) {
        self.title = title; self.pages = pages; self.content = content
        _selection = State(initialValue: pages.first?.id)
    }
    public var body: some View {
        NavigationSplitView {
            List(pages, selection: $selection) { page in Label(page.title, systemImage: page.symbol).tag(page.id) }
                .listStyle(.sidebar).navigationTitle(title)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: KitSpacing.group) {
                    AppHeader(title: pages.first { $0.id == selection }?.title ?? title,
                              subtitle: title, symbol: pages.first { $0.id == selection }?.symbol ?? "app")
                    content(selection ?? pages.first?.id ?? "")
                }.padding(KitSpacing.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(minWidth: 720, minHeight: 480)
    }
}

public struct AppHeader: View {
    let title: String; let subtitle: String; let symbol: String
    public init(title: String, subtitle: String = "", symbol: String) { self.title = title; self.subtitle = subtitle; self.symbol = symbol }
    public var body: some View {
        HStack(spacing: KitSpacing.medium) {
            Image(systemName: symbol).font(.title).foregroundStyle(.tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                if !subtitle.isEmpty { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
            }
        }
    }
}

public struct SettingsSection<Content: View>: View {
    let title: String; let content: Content
    public init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: KitSpacing.group) { content }
                .padding(KitSpacing.small).frame(maxWidth: .infinity, alignment: .leading)
        } label: { Text(title).font(.headline) }
    }
}

public struct SettingRow<Content: View>: View {
    let title: String; let detail: String; let content: Content
    public init(_ title: String, detail: String = "", @ViewBuilder content: () -> Content) { self.title = title; self.detail = detail; self.content = content() }
    public var body: some View {
        HStack(spacing: KitSpacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: KitSpacing.medium)
            content
        }
    }
}

public struct ToggleRow: View {
    let title: String; let detail: String; @Binding var value: Bool
    public init(_ title: String, detail: String = "", isOn: Binding<Bool>) { self.title = title; self.detail = detail; _value = isOn }
    public var body: some View { SettingRow(title, detail: detail) { Toggle(title, isOn: $value).labelsHidden().toggleStyle(.switch).accessibilityLabel(title) } }
}

public struct SliderRow: View {
    let title: String; let range: ClosedRange<Double>; let unit: String; @Binding var value: Double
    @State private var input = ""
    @FocusState private var editing: Bool
    public init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, unit: String = "") { self.title = title; _value = value; self.range = range; self.unit = unit }
    private var bounded: Binding<Double> { Binding(get: { value }, set: { if $0.isFinite { value = min(range.upperBound, max(range.lowerBound, $0)) } }) }
    public var body: some View {
        VStack(alignment: .leading, spacing: KitSpacing.small) {
            HStack {
                Text(title); Spacer()
                TextField(title, text: $input).focused($editing)
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 80).accessibilityLabel(title + " – Zahlenwert")
                    .onSubmit { commit() }
                    .onChange(of: editing) { _, active in if !active { commit() } }
                if !unit.isEmpty { Text(unit).foregroundStyle(.secondary) }
            }
            Slider(value: bounded, in: range).accessibilityLabel(title)
        }.onAppear { input = formatted() }
        .onChange(of: value) { _, _ in if !editing { input = formatted() } }
    }
    private func formatted() -> String { value.formatted(.number.grouping(.never).precision(.fractionLength(0...3))) }
    private func commit() {
        if let accepted = NumericInput.accept(input, in: range) { bounded.wrappedValue = accepted }
        input = formatted()
    }
}

public struct ChoiceRow<Selection: Hashable>: View {
    let title: String; let options: [(String, Selection)]; @Binding var value: Selection
    public init(_ title: String, selection: Binding<Selection>, options: [(String, Selection)]) { self.title = title; _value = selection; self.options = options }
    public var body: some View {
        Picker(title, selection: $value) { ForEach(options.indices, id: \.self) { i in Text(options[i].0).tag(options[i].1) } }
    }
}

public struct PermissionRow: View {
    let title: String; let detail: String; let granted: Bool; let action: () -> Void
    public init(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) { self.title = title; self.detail = detail; self.granted = granted; self.action = action }
    public var body: some View {
        HStack(spacing: KitSpacing.medium) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(granted ? Color.green : Color.secondary)
                .accessibilityLabel(granted ? "Freigegeben" : "Freigabe fehlt")
            SettingRow(title, detail: detail) { if !granted { Button("Freigeben …", action: action) } }
        }
    }
}

public struct StatusMessage: View {
    let text: String; let error: Bool
    public init(_ text: String, error: Bool = false) { self.text = text; self.error = error }
    public var body: some View { Text(text).font(.callout).foregroundStyle(error ? Color.red : Color.secondary).fixedSize(horizontal: false, vertical: true) }
}

public struct EmptyState: View {
    let title: String; let detail: String; let symbol: String
    public init(_ title: String, detail: String, symbol: String = "tray") { self.title = title; self.detail = detail; self.symbol = symbol }
    public var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(detail)) }
}

public struct LoginItemRow: View {
    @State private var login = LoginService()
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: KitSpacing.small) {
            ToggleRow("Beim Anmelden starten", isOn: Binding(get: { login.enabled || login.needsApproval }, set: login.setEnabled))
            if login.needsApproval { Button("Anmeldeobjekte öffnen …", action: login.openSettings) }
            if !login.message.isEmpty { StatusMessage(login.message, error: true) }
        }.onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }
}

public struct AppInfoSection: View {
    let name: String
    public init(_ name: String) { self.name = name }
    public var body: some View {
        SettingsSection(name) {
            Text("Version " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"))
            Text("Teil von MacFitKit").foregroundStyle(.secondary)
            Link("Quellcode und Downloads", destination: URL(string: "https://github.com/dariuscorvus/macfitkit")!)
        }
    }
}
