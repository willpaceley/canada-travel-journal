//
//  DataModel.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-05.
//

import CloudKit

protocol DataModelDelegate: AnyObject {
    func dataModelDidLoadTrips()
    func dataModel(didHaveLoadError error: Error)
    func dataModelDidSaveTrips()
    func dataModel(didHaveSaveError error: Error)
}

class DataModel {
    private(set) var trips = [Trip]()
    
    var totalDays: Int {
        trips.reduce(0) { $0 + $1.days }
    }
    
    var cloudKitManager: CloudKitManager!
    weak var delegate: DataModelDelegate!
    
    // MARK: - CRUD Methods
    func add(trip: Trip) {
        trips.append(trip)
        sortByReverseChronological()
    }
    
    func delete(trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips.remove(at: index)
        } else {
            print("There was a problem finding the index of the trip to delete")
        }
    }
    
    // MARK: - Data Persistence
    func loadTrips() {
        guard let accountStatus = cloudKitManager.accountStatus else {
            print("CloudKit account status had not been determined yet.")
            return
        }
        
        let iCloudDataIsStale = UserDefaults.standard.bool(forKey: iCloudDataIsStaleKey)
        print("iCloud data is stale? \(iCloudDataIsStale)")
        
        if accountStatus == .available && !iCloudDataIsStale {
            cloudKitManager.fetchTrips { [weak self] result in
                switch result {
                case .success(let trips):
                    if let trips {
                        self?.trips = trips
                    }
                    DispatchQueue.main.async {
                        self?.delegate.dataModelDidLoadTrips()
                    }
                    return
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.delegate.dataModel(didHaveLoadError: error)
                    }
                }
            }
        } else {
            let fileManager = FileManager.default
            if fileManager.tripDataFileExists() {
                print("Loading trips from on-device storage.")
                let url = fileManager.getTripDataURL()
                do {
                    let tripData = try Data(contentsOf: url)
                    trips = try JSONDecoder().decode([Trip].self, from: tripData)
                    print("Trips successfully decoded from on-device storage.")
                } catch {
                    print("An error occured loading trips from device storage: \(error.localizedDescription)")
                    delegate.dataModel(didHaveLoadError: error)
                    return
                }
                delegate.dataModelDidLoadTrips()
            }
        }
    }
    
    func saveTrips() {
        guard let accountStatus = cloudKitManager.accountStatus else {
            print("CloudKit account status had not been determined yet.")
            return
        }
        
        guard !trips.isEmpty else {
            print("There were no trips to save.")
            return
        }
        
        // Persist in iCloud as source of truth across all iOS devices
        if accountStatus == .available {
            cloudKitManager.postTrips(trips: trips) { [weak self] result in
                switch result {
                case .success(_):
                    print("Trips successfully saved to CloudKit DB.")
                    UserDefaults.standard.setValue(false, forKey: iCloudDataIsStaleKey)
                    DispatchQueue.main.async {
                        self?.delegate.dataModelDidSaveTrips()
                    }
                case .failure(let error):
                    print("An error occurred while attempting to save trips to CloudKit DB.")
                    DispatchQueue.main.async {
                        self?.delegate.dataModel(didHaveSaveError: error)
                    }
                }
            }
        } else {
            // Toggle flag in UserDefaults to indicate iCloud data is stale
            UserDefaults.standard.set(true, forKey: iCloudDataIsStaleKey)
        }
        
        // Persist data on-device in case CloudKit is permanently or temporarily unavailable
        let url = FileManager.default.getTripDataURL()
        do {
            let jsonData = try JSONEncoder().encode(trips)
            try jsonData.write(to: url)
            print("Trip data successfully saved in the app's documents directory.")
        } catch {
            print("An error occurred saving trip data locally: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    func createCSV() -> String {
        var contents = "Destination,Departure Date,Return Date,Days,Reason\n"
        
        for trip in trips {
            let departureDate = trip.departureDate.format()
            let returnDate = trip.departureDate.format()
            
            contents += "\"\(trip.destination)\",\"\(departureDate)\",\"\(returnDate)\",\"\(trip.days)\",\"\(trip.reason)\"\n"
        }
        
        return contents
    }
    
    private func sortByReverseChronological() {
        trips.sort { $0.departureDate > $1.departureDate }
    }
}
