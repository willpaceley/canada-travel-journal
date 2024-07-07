//
//  MockConnectivityManagerDelegate.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-07-07.
//

import Network
import XCTest
@testable import TravelJournal

class MockConnectivityManagerDelegate: ConnectivityManagerDelegate {
    var statusChangedCallCount = 0
    var statusChangedArgs: [NWPath.Status] = []
    
    func connectivityManagerStatusChanged(to status: NWPath.Status) {
        statusChangedCallCount += 1
        statusChangedArgs.append(status)
    }
    
    func verifyStatusChangedCalled(
        numberOfTimes: Int,
        with statuses: [NWPath.Status],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(statusChangedCallCount, numberOfTimes, "call count", file: file, line: line)
        XCTAssertEqual(statusChangedArgs, statuses, "status arguments", file: file, line: line)
    }
}
