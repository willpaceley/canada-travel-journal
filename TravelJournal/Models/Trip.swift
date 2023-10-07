//
//  Trip.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import Foundation

class Trip: Codable {
    var id: String
    var departureDate: Date
    var returnDate: Date
    var destination: String
    var reason: String
    
    init(
        id: String = UUID().uuidString,
        departureDate: Date,
        returnDate: Date,
        destination: String,
        reason: String
    ) {
        self.id = id
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.destination = destination
        self.reason = reason
    }
    
    // TODO: - Check business logic matches IRCC calculator
    var days: Int {
        let components = Calendar.current.dateComponents([.day], from: departureDate, to: returnDate)
        
        if let day = components.day {
            return day + 1
        } else {
            return 0
        }
    }
}
