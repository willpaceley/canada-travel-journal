//
//  ConnectivityManagerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-07-06.
//

import XCTest
import Network
@testable import TravelJournal

final class ConnectivityManagerTests: XCTestCase {
    // What do we want to test?
    // That the status is changed properly when pathUpdateHandler is called
    // That the status doesn't change when same status is called
    func test_connectivityUpdated_withNilStatus_shouldChangeToNewStatus() {
        let monitor = TestablePathMonitor()
        let sut = ConnectivityManager(monitor: monitor)
        let delegate = ConnectivityManagerDelegateSpy()
        sut.delegate = delegate
        XCTAssertNil(sut.status, "precondition")
        
        // Act: Need to somehow fake calling the pathUpdateHandler
        // The problem is we can't init an NWPath
        let newStatus: NWPath.Status = .satisfied
        sut.connectivityUpdated(to: newStatus)
        
        XCTAssertEqual(sut.status, newStatus)
    }
}

class TestablePathMonitor: PathMonitor {
    func start(
        queue: DispatchQueue = DispatchQueue(label: "TEST")
    ) {}
    
    var pathUpdateHandler: (@Sendable (NWPath) -> Void)?
}

class ConnectivityManagerDelegateSpy: ConnectivityManagerDelegate {
    var statusChangedCallCount = 0
    var statusChangedArgs: [NWPath.Status] = []
    
    func connectivityManagerStatusChanged(to status: NWPath.Status) {
        statusChangedCallCount += 1
        statusChangedArgs.append(status)
    }
}
