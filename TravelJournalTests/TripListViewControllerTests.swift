//
//  TripListViewControllerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-05-08.
//

@testable import TravelJournal
import XCTest
import Network

final class TripListViewControllerTests: XCTestCase {

    func test_outlets_shouldBeConnected() {
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        let sut: TripListViewController = storyboard.instantiateViewController(
            identifier: String(describing: TripListViewController.self)
        )
        
        sut.dataService = TripDataService(
            cloudKitManager: TestableCloudKitManager(),
            connectivityManager: TestableConnectivityManager()
        )
        sut.loadViewIfNeeded()
        
        XCTAssertNotNil(sut.activityIndicator, "activity indicator")
        XCTAssertNotNil(sut.persistenceStatusButton, "persistence status button")
        XCTAssertNotNil(sut.addTripButton, "add trip button")
        XCTAssertNotNil(sut.shareButton, "share button")
    }

}

// MARK: Testable Dependencies
class TestableCloudKitManager: CloudKitManager {
    override init() {
        print("TestableCloudKitManager init() did not set up notification observation")
    }
}

class TestableConnectivityManager: ConnectivityManager {
    override init() {
        print("TestableConnectivityManager init() did not set up path update handler")
    }
    
    override func pathUpdateHandler(_ path: NWPath) {
        print("Mocked pathUpdateHandler fired")
    }
}
