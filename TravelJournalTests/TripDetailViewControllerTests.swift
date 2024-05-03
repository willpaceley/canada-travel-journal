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
    
}
