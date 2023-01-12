//
//  Trip.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import Foundation

struct Trip: Encodable, Decodable {
    let id: String
    
    var departureDate: Date
    var returnDate: Date
    var destination: String
    var reason: String
    
    var days: Int {
        let components = Calendar.current.dateComponents([.day], from: departureDate, to: returnDate)
        
        if let day = components.day {
            return day + 1
        } else {
            return 0
        }
    }
}
