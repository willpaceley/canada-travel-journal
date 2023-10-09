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
        
        if accountStatus == .available {
            cloudKitManager.fetchTrips { [weak self] result in
                switch result {
                case .success(let trips):
                    if let trips {
                        self?.trips = trips
                    }
                    DispatchQueue.main.async {
                        self?.delegate.dataModelDidLoadTrips()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.delegate.dataModel(didHaveLoadError: error)
                    }
                }
            }
        }
    }
    
    func saveTrips() {
        guard let accountStatus = cloudKitManager.accountStatus else {
            print("CloudKit account status had not been determined yet.")
            return
        }
        
        if accountStatus == .available {
            cloudKitManager.postTrips(trips: trips) { [weak self] result in
                switch result {
                case .success(_):
                    print("Trips successfully saved to CloudKit DB.")
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
