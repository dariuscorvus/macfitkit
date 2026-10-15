import Testing
import Foundation
@testable import MacFitKitCore

@Test func menuLeaseNeedsAcknowledgementAndExpires() {
    var lease = MenuLease()
    #expect(!lease.isConnected(at: 10))
    lease.acknowledge(at: 10)
    #expect(lease.isConnected(at: 12.99))
    #expect(!lease.isConnected(at: 13))
    #expect(!lease.isConnected(at: 9))
    lease.acknowledge(at: 14)
    #expect(lease.isConnected(at: 14))
    lease.clear()
    #expect(!lease.isConnected(at: 14))
}
@Test func protocolRejectsUnknownVersionAndMalformedCommands() throws {
    let command = ToolCommand.setEnabled(false)
    #expect(BridgeEnvelope<ToolCommand>.decode(try BridgeEnvelope(command).encoded()) == command)
    #expect(BridgeEnvelope<ToolCommand>.decode(try BridgeEnvelope(command, version: 2).encoded()) == nil)
    #expect(BridgeEnvelope<ToolCommand>.decode(Data("bad".utf8)) == nil)
    #expect(BridgeEnvelope<ToolCommand>.decode(Data(repeating: 0, count: 65_536)) == nil)
}
@Test func identitiesAreStableAndDistinct() {
    #expect(Set(ToolID.allCases.map(\.bundleIdentifier)).count == 3)
    #expect(ToolID.liveDesktop.bundleIdentifier == "tech.highbyte.LiveDesktop.prototype")
    #expect(ToolID.focusFrame.bundleIdentifier == "de.highbytetech.FocusFrame")
}
