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
    
    func occursAfter(_ date: Date) -> Bool {
        if self.isTheSameDate(as: date) {
            return false
        }
        return self > date
    }
    
    func occursOnOrAfter(_ date: Date) -> Bool {
        return self.isTheSameDate(as: date) || self > date
    }
    
    // MARK: - Private Methods
    // Compare two dates, ignoring time of day
    private func isTheSameDate(as date: Date) -> Bool {
        let components1 = Calendar.current.dateComponents([.year, .month, .day], from: self)
        let components2 = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        guard components1.year == components2.year else {
            return false
        }
        guard components1.month == components2.month else {
            return false
        }
        guard components1.day == components2.day else {
            return false
        }
        
        return true
    }
}
