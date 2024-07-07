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
    private var monitor: TestablePathMonitor!
    private var sut: ConnectivityManager!
    private var delegate: ConnectivityManagerDelegateSpy!
    
    // MARK: - setUp and tearDown
    override func setUp() {
        super.setUp()
        monitor = TestablePathMonitor()
        sut = ConnectivityManager(monitor: monitor)
        delegate = ConnectivityManagerDelegateSpy()
        sut.delegate = delegate
    }
    
    override func tearDown() {
        monitor = nil
        sut = nil
        delegate = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func test_connectivityUpdated_withNilStatus_shouldChangeToNewStatus() {
        XCTAssertNil(sut.status, "precondition")
        let newStatus: NWPath.Status = .satisfied
        sut.connectivityUpdated(to: newStatus)
        XCTAssertEqual(sut.status, newStatus)
    }
    
    // TODO: Test status is changed when different status is received from connectivityUpdated
    // TODO: Test status doesn't change when same status is called
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
