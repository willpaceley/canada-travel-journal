//
//  Date+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-10.
//

import Foundation

extension Date {
    func format() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM. dd, yyyy"
        let formattedDate = dateFormatter.string(from: self)
        
        return formattedDate
    }
}
