import Foundation

/// Snapshot undo for a value-type state on an `UndoManager`. Each step stores the value it replaced; undoing registers the redo the same way.
@MainActor public final class SnapshotHistory<Value: Equatable> {
    public weak var undoManager: UndoManager?
    private let read: () -> Value, write: (Value) -> Void
    private var interactionStart: Value?
    private var coalescing: (key: String, until: Date)?
    public var isInteracting: Bool { interactionStart != nil }

    /// `read`/`write` access the live state; `write` must not record history itself.
    public init(read: @escaping () -> Value, write: @escaping (Value) -> Void) { self.read = read; self.write = write }

    /// Applies `change` as one undo step. Changes with the same `coalesceKey` within `window` seconds share one step (colour panels, typing).
    public func edit(_ name: String, coalesceKey: String? = nil, window: TimeInterval = 1, now: Date = Date(), _ change: (inout Value) -> Void) {
        let old = read(); var new = old; change(&new)
        guard new != old else { return }
        write(new)
        if let key = coalesceKey, let current = coalescing, current.key == key, now < current.until { coalescing = (key: key, until: now + window); return }
        coalescing = coalesceKey.map { (key: $0, until: now + window) }
        register(old, name: name)
    }

    /// One undo step for a whole drag: `begin`, any number of `interact`, then `end`.
    public func begin() { if interactionStart == nil { interactionStart = read() } }
    public func interact(_ change: (inout Value) -> Void) { var value = read(); change(&value); if value != read() { write(value) } }
    public func end(_ name: String) {
        guard let start = interactionStart else { return }
        interactionStart = nil; coalescing = nil
        if read() != start { register(start, name: name) }
    }

    private func register(_ old: Value, name: String) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { history in MainActor.assumeIsolated { history.restore(old, name: name) } }
        undoManager.setActionName(name)
    }

    private func restore(_ value: Value, name: String) {
        let current = read(); coalescing = nil; interactionStart = nil
        write(value); register(current, name: name)
    }
}
