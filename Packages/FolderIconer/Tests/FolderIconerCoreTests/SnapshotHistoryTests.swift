import Foundation
import Testing
@testable import FolderIconerCore

@MainActor private final class Box {
    var value = 0
    let manager = UndoManager()
    lazy var history = SnapshotHistory(read: { [unowned self] in value }, write: { [unowned self] in value = $0 })
    init() { manager.groupsByEvent = false; history.undoManager = manager }
    /// One event's worth of undo registrations. Empty groups would count as undo steps here, unlike with `groupsByEvent`.
    func step(_ body: () -> Void) { manager.beginUndoGrouping(); body(); manager.endUndoGrouping() }
}

@MainActor @Test func editUndoesAndRedoesBySnapshot() {
    let box = Box()
    box.step { box.history.edit("Set") { $0 = 1 } }
    box.step { box.history.edit("Set") { $0 = 2 } }
    #expect(box.manager.undoActionName == "Set")
    box.manager.undo(); #expect(box.value == 1)
    box.manager.undo(); #expect(box.value == 0 && !box.manager.canUndo)
    box.manager.redo(); box.manager.redo(); #expect(box.value == 2 && !box.manager.canRedo)
}

@MainActor @Test func unchangedEditRegistersNothing() {
    let box = Box()
    box.history.edit("Same") { $0 = 0 }
    #expect(!box.manager.canUndo)
}

@MainActor @Test func interactionIsOneUndoStep() {
    let box = Box()
    box.history.begin()
    for value in 1...5 { box.history.interact { $0 = value } }
    box.step { box.history.end("Drag") }
    #expect(box.value == 5)
    box.manager.undo(); #expect(box.value == 0 && !box.manager.canUndo)
    box.manager.redo(); #expect(box.value == 5)
}

@MainActor @Test func coalescedEditsShareOneStepWithinTheWindow() {
    let box = Box(), start = Date()
    box.step { box.history.edit("Colour", coalesceKey: "c", now: start) { $0 = 1 } }
    box.history.edit("Colour", coalesceKey: "c", now: start + 0.5) { $0 = 2 }
    box.step { box.history.edit("Colour", coalesceKey: "c", now: start + 3) { $0 = 3 } }
    box.manager.undo(); #expect(box.value == 2)
    box.manager.undo(); #expect(box.value == 0 && !box.manager.canUndo)
}
