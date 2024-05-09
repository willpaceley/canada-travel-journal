//
//  TripListViewControllerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-05-08.
//

@testable import TravelJournal
import XCTest
import Network
import ViewControllerPresentationSpy

final class TripListViewControllerTests: XCTestCase {
    private var alertVerifier: AlertVerifier!
    private var sut: TripListViewController!
    
    // MARK: - setUp and tearDown
    @MainActor
    override func setUp() {
        super.setUp()
        alertVerifier = AlertVerifier()
        
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        sut = storyboard.instantiateViewController(
            identifier: String(describing: TripListViewController.self)
        )
        sut.dataService = TripDataService(
            cloudKitManager: TestableCloudKitManager(),
            connectivityManager: TestableConnectivityManager()
        )
        sut.loadViewIfNeeded()
    }
    
    override func tearDown() {
        alertVerifier = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func test_outlets_shouldBeConnected() {
        XCTAssertNotNil(sut.activityIndicator, "activity indicator")
        XCTAssertNotNil(sut.persistenceStatusButton, "persistence status button")
        XCTAssertNotNil(sut.addTripButton, "add trip button")
        XCTAssertNotNil(sut.shareButton, "share button")
    }
    
    @MainActor
    func test_tappingStatusButton_shouldShowAlert() {
        let statusButton = sut.persistenceStatusButton.customView as! UIButton
        statusButton.tap()
        let alert = PersistenceAlertFactory.alert(for: .unknown)
        
        alertVerifier.verify(
            title: alert.title,
            message: alert.message,
            animated: true,
            actions: [
                .destructive("Close App"),
                .default("OK"),
            ],
            preferredStyle: .actionSheet,
            presentingViewController: sut
        )
    }
}

// MARK: Testable Dependencies
class TestableCloudKitManager: CloudKitManager {
    override init() {
        // Override init to avoid setting up notification observation
    }
}

class TestableConnectivityManager: ConnectivityManager {
    override init() {
        // Override init to avoid setting up path update handler
    }
    
    override func pathUpdateHandler(_ path: NWPath) {
        // Do mock work in here
    }
}
