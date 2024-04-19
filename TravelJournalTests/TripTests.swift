//
//  TripTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-04-19.
//

@testable import TravelJournal
import XCTest

final class TripTests: XCTestCase {
    
    private var trip: Trip!
    
    override func setUp() {
        super.setUp()
        trip = Trip(departureDate: Date(), returnDate: Date(), destination: "", reason: "")
    }
    
    override func tearDown() {
        trip = nil
        super.tearDown()
    }

    func test_trip_withSameDepartureAndReturnDate_returns1() {
        // Arrange
        let date = Date()
        trip.departureDate = date
        trip.returnDate = date
        
        // Act
        let result = trip.days
        
        // Assert
        XCTAssertEqual(result, 1)
    }
    
    func test_trip_withDatesTwoDaysApart_returns2() {
        // Arrange
        let today = Date()
        let twoDaysFromNow = Date(timeInterval: 172800, since: today)
        trip.departureDate = today
        trip.returnDate = twoDaysFromNow
        
        // Act
        let result = trip.days
        
        // Assert
        XCTAssertEqual(result, 2)
    }
    
    func test_trip_withReturnDatePriorToDeparture_return0() {
        // Arrange
        let today = Date()
        let yesterday = Date(timeInterval: -86400, since: today)
        trip.departureDate = today
        trip.returnDate = yesterday
        
        // Act
        let result = trip.days
        
        // Assert
        XCTAssertEqual(result, 0)
    }
}
