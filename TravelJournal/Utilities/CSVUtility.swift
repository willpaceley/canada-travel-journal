//
//  CSVUtility.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-13.
//

import Foundation

struct CSVUtility {
    static func getCSVFilePath() -> URL {
        let directory = FileManager.default.temporaryDirectory
        return directory.appendingPathComponent(csvFileName)
    }
    
    static func generateCSVContent(from trips: [Trip]) -> String {
        var contents = "Destination,Departure Date,Return Date,Days,Reason\n"
        
        for trip in trips {
            let departureDate = trip.departureDate.format()
            let returnDate = trip.departureDate.format()
            
            contents += "\"\(trip.destination)\",\"\(departureDate)\",\"\(returnDate)\",\"\(trip.days)\",\"\(trip.reason)\"\n"
        }
        
        return contents
    }
    
    static func writeCSVFile(csvContent: String) throws {
        let filePath = CSVUtility.getCSVFilePath()
        try csvContent.write(to: filePath, atomically: true, encoding: .utf8)
    }
}
