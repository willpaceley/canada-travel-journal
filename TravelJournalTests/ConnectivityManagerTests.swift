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
    private var mockDelegate: MockConnectivityManagerDelegate!
    
    // MARK: - setUp and tearDown
    override func setUp() {
        super.setUp()
        monitor = TestablePathMonitor()
        sut = ConnectivityManager(monitor: monitor)
        mockDelegate = MockConnectivityManagerDelegate()
        sut.delegate = mockDelegate
    }
    
    override func tearDown() {
        monitor = nil
        sut = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func test_connectivityUpdated_withNilStatus_shouldChangeToNewStatus() {
        XCTAssertNil(sut.status, "precondition")
        let newStatus: NWPath.Status = .satisfied
        sut.connectivityUpdated(to: newStatus)
        
        mockDelegate.verifyStatusChangedCalled(numberOfTimes: 1, with: [newStatus])
        XCTAssertEqual(sut.status, newStatus)
    }
    
    func test_connectivityUpdated_withExistingStatus_shouldChangeToNewStatus() {
        let initialStatus: NWPath.Status = .satisfied
        sut.connectivityUpdated(to: initialStatus)
        XCTAssertEqual(sut.status, initialStatus, "precondition")
        
        let newStatus: NWPath.Status = .unsatisfied
        sut.connectivityUpdated(to: newStatus)
        
        mockDelegate.verifyStatusChangedCalled(numberOfTimes: 2, with: [initialStatus, newStatus])
        XCTAssertNotEqual(sut.status, initialStatus)
    }
    
    func test_connectivityUpdated_withSameStatus_shouldNotChangeStatus() {
        let initialStatus: NWPath.Status = .requiresConnection
        sut.connectivityUpdated(to: initialStatus)
        XCTAssertEqual(sut.status, initialStatus, "precondition")
        
        let newStatus: NWPath.Status = .requiresConnection
        sut.connectivityUpdated(to: newStatus)
        
        mockDelegate.verifyStatusChangedCalled(numberOfTimes: 1, with: [initialStatus])
        XCTAssertEqual(sut.status, initialStatus)
    }
}

class TestablePathMonitor: PathMonitor {
    func start(
        queue: DispatchQueue = DispatchQueue(label: "TEST")
    ) {}
    
    var pathUpdateHandler: (@Sendable (NWPath) -> Void)?
}

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
