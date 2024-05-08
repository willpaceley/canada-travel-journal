//
//  TripDetailViewControllerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-04-22.
//

@testable import TravelJournal
import XCTest

final class TripDetailViewControllerTests: XCTestCase {
    private var sut: TripDetailViewController!
    
    override func setUp() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        sut = storyboard.instantiateViewController(
            identifier: String(describing: TripDetailViewController.self)
        )
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_outlets_shouldBeConnected() {
        sut.loadViewIfNeeded()
        
        XCTAssertNotNil(sut.addTripButton, "add trip button")
        XCTAssertNotNil(sut.countryLabel, "country label")
        XCTAssertNotNil(sut.reasonField, "reason field")
        XCTAssertNotNil(sut.returnPicker, "return picker")
        XCTAssertNotNil(sut.departurePicker, "departure picker")
        XCTAssertNotNil(sut.doneButton, "done button")
    }
        
    func test_addTripButton_whileEditingTrip_shouldBeHidden() {
        sut.tripToEdit = Trip(departureDate: .now, returnDate: .now, destination: "", reason: "")
        sut.loadViewIfNeeded()
        
        XCTAssertTrue(sut.addTripButton.isHidden)
    }
    
    func test_addTripButton_whileAddingTrip_shouldNotBeHidden() {
        sut.tripToEdit = nil
        sut.loadViewIfNeeded()
        
        XCTAssertFalse(sut.addTripButton.isHidden)
    }
}
