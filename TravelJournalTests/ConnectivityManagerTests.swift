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
        XCTAssertNil(sut.status, "precondition")
        
        // Act: Need to somehow fake calling the pathUpdateHandler
        // The problem is we can't init an NWPath
    }
}

class TestablePathMonitor: PathMonitor {
    func start(
        queue: DispatchQueue = DispatchQueue(label: "TEST")
    ) {}
    
    var pathUpdateHandler: (@Sendable (NWPath) -> Void)?
}
