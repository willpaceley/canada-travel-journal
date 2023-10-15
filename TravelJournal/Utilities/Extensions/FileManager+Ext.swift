//
//  FileManager+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-10-09.
//

import Foundation

extension FileManager {
    private func getDocumentsDirectory() -> URL {
        return self.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func getTripDataURL() -> URL {
        let documentDirectory = getDocumentsDirectory()
//        print(documentDirectory)
        let url: URL
        if #available(iOS 16.0, *) {
            url = documentDirectory.appending(path: "TripData.json")
        } else {
            url = documentDirectory.appendingPathComponent("TripData.json")
        }
        return url
    }
    
    func tripDataFileExists() -> Bool {
        let tripURL = getTripDataURL()
        return self.fileExists(atPath: tripURL.relativePath)
    }
}
