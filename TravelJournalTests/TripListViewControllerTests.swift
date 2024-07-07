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
    private var sut: TripListViewController!
    
    // MARK: - setUp and tearDown
    @MainActor
    override func setUp() {
        super.setUp()
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        sut = storyboard.instantiateViewController(
            identifier: String(describing: TripListViewController.self)
        )
        sut.dataService = TripDataService(
            cloudKitManager: CloudKitManager(),
            connectivityManager: ConnectivityManager(monitor: TestablePathMonitor())
        )
        sut.loadViewIfNeeded()
    }
    
    override func tearDown() {
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
        let alertVerifier = AlertVerifier()
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
    
    @MainActor
    func test_tappingAddTripButton_shouldShowTripDetailViewController() {
        let presentationVerifier = PresentationVerifier()
        putInWindow(sut)
        
        sut.addTripButton.tap()
        
        let tripDetailVC: TripDetailViewController? = presentationVerifier.verify(
            animated: true,
            presentingViewController: sut
        )
        XCTAssertNotNil(tripDetailVC, "presented view controller was nil")
        XCTAssertEqual(tripDetailVC?.title, "Add New Trip")
    }
}
