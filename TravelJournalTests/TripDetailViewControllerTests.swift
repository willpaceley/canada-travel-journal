//
//  TripDetailViewControllerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-04-22.
//

@testable import TravelJournal
import XCTest

final class TripDetailViewControllerTests: XCTestCase {

    func test_loading() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let sut: TripDetailViewController = sb.instantiateViewController(
            identifier: String(describing: TripDetailViewController.self)
        )
        sut.loadViewIfNeeded()
        
        XCTAssertNotNil(sut.addTripButton)
    }
    
    func test_outlets_shouldBeConnected() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let sut: TripDetailViewController = sb.instantiateViewController(
            identifier: String(describing: TripDetailViewController.self)
        )
        sut.loadViewIfNeeded()
        
        XCTAssertNotNil(sut.addTripButton, "add trip button")
        XCTAssertNotNil(sut.countryLabel, "country label")
        XCTAssertNotNil(sut.reasonField, "reason field")
        XCTAssertNotNil(sut.returnPicker, "return picker")
        XCTAssertNotNil(sut.departurePicker, "departure picker")
        XCTAssertNotNil(sut.doneButton, "done button")
    }
        
    func test_addTripButton_whileEditingTrip_shouldBeHidden() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let sut: TripDetailViewController = sb.instantiateViewController(
            identifier: String(describing: TripDetailViewController.self)
        )
        
        sut.tripToEdit = Trip(departureDate: .now, returnDate: .now, destination: "", reason: "")
        sut.loadViewIfNeeded()
        
        XCTAssertTrue(sut.addTripButton.isHidden)
    }
    
    func test_addTripButton_whileAddingTrip_shouldNotBeHidden() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let sut: TripDetailViewController = sb.instantiateViewController(
            identifier: String(describing: TripDetailViewController.self)
        )
        
        sut.tripToEdit = nil
        sut.loadViewIfNeeded()
        
        XCTAssertFalse(sut.addTripButton.isHidden)
    }
}
