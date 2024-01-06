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
    
    var days: Int {
        let components = Calendar.current.dateComponents([.day], from: departureDate, to: returnDate)
        
        if let days = components.day {
            // If returning same day, count as 1 day away from Canada
            return days != 0 ? days : 1
        } else {
            return 0
        }
    }
}
