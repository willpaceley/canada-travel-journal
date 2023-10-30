//
//  DataModel.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-05.
//

import CloudKit
import Network

protocol DataModelDelegate: AnyObject {
    func dataModelDidChange()
    func dataModelDidLoadTrips()
    func dataModel(didHaveLoadError error: Error?)
    func dataModel(didHaveSaveError error: Error)
}

class DataModel {
    private(set) var trips = [Trip]()
    private var hasUnsavedChanges = false
    
    var persistenceStatus: PersistenceStatus = .unknown {
        didSet {
            print("persistenceStatus Changed from: \(oldValue) to: \(persistenceStatus)")
        }
    }
    var totalDays: Int {
        trips.reduce(0) { $0 + $1.days }
    }
    
    var connectivityManager: ConnectivityManager
    weak var cloudKitManager: CloudKitManager!
    weak var delegate: DataModelDelegate!
    
    // MARK: - Initializer
    init(connectivityManager: ConnectivityManager) {
        self.connectivityManager = connectivityManager
        self.connectivityManager.delegate = self
        self.connectivityManager.startMonitor()
    }
    
    // MARK: - CRUD Methods
    func add(trip: Trip) {
        trips.append(trip)
        sortByReverseChronological()
        hasUnsavedChanges = true
        delegate.dataModelDidChange()
    }
    
    func updatedTrip() {
        hasUnsavedChanges = true
    }
    
    func delete(trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips.remove(at: index)
            hasUnsavedChanges = true
            delegate.dataModelDidChange()
        } else {
            print("There was a problem finding the index of the trip to delete")
        }
    }
    
    // MARK: - Data Persistence
    func loadTrips() {
        guard let accountStatus = cloudKitManager.accountStatus else {
            print("CloudKit account status was nil. Did not load trips.")
            return
        }
        
        guard !hasUnsavedChanges else {
            print("There are unsaved changes in the data model. Did not load trips.")
            // TODO: Add custom error, remove optionality from protocol
            delegate.dataModel(didHaveLoadError: nil)
            return
        }
        
        let iCloudDataIsStale = UserDefaults.standard.bool(forKey: iCloudDataIsStaleKey)
        
        if persistenceStatus == .iCloudAvailable && !iCloudDataIsStale {
            cloudKitManager.fetchTrips { [weak self] result in
                switch result {
                case .success(let trips):
                    if let trips {
                        self?.trips = trips
                    }
                    DispatchQueue.main.async {
                        self?.delegate.dataModelDidLoadTrips()
                        self?.delegate.dataModelDidChange()
                    }
                    return
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.delegate.dataModel(didHaveLoadError: error)
                    }
                }
            }
            return
        }
        
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
            delegate.dataModelDidChange()
        }
    }
    
    func saveTrips() {
        guard let accountStatus = cloudKitManager.accountStatus else {
            print("CloudKit account status was nil, did not save trips.")
            return
        }

        // Persist in iCloud as source of truth across all iOS devices
        if accountStatus == .available {
            cloudKitManager.postTrips(trips: trips) { [weak self] result in
                switch result {
                case .success(_):
                    print("Trips successfully saved to CloudKit DB.")
                    self?.cloudKitManager.iCloudDataIsStale = false
                    self?.hasUnsavedChanges = false
                case .failure(let error):
                    print("An error occurred while attempting to save trips to CloudKit DB.")
                    DispatchQueue.main.async {
                        self?.delegate.dataModel(didHaveSaveError: error)
                    }
                }
            }
        } else {
            // Toggle flag in UserDefaults to indicate iCloud data is stale
            cloudKitManager.iCloudDataIsStale = true
        }
        
        // Persist data on-device in case CloudKit is permanently or temporarily unavailable
        let url = FileManager.default.getTripDataURL()
        do {
            let jsonData = try JSONEncoder().encode(trips)
            try jsonData.write(to: url)
            print("Trip data successfully saved in the app's documents directory.")
            hasUnsavedChanges = false
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

// MARK: - ConnectivityManagerDelegate
extension DataModel: ConnectivityManagerDelegate {
    func connectivityManagerStatusChanged(to status: NWPath.Status) {
        guard status != .satisfied else {
            print("Device is not connected to a network.")
            persistenceStatus = .networkUnavailable
            return
        }
        
        // If user was previously offline, check if CloudKit status changed
        if persistenceStatus == .networkUnavailable {
            // might need to wrap this in a timer as it takes time for internet to fire up?
            cloudKitManager.requestAccountStatus()
        }
    }
}

// MARK: - PersistenceStatus
enum PersistenceStatus {
    case iCloudAvailable
    case iCloudUnavailable
    case networkUnavailable
    case unknown
}
