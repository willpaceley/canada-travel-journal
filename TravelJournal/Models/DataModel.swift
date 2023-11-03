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
    func dataModelPersistenceStatus(changedTo status: PersistenceStatus)
}

class DataModel {
    private(set) var trips = [Trip]()
    private var hasUnsavedChanges = false
    
    let connectivityManager: ConnectivityManager
    let cloudKitManager: CloudKitManager
    
    var persistenceStatus: PersistenceStatus = .unknown {
        didSet {
            DispatchQueue.main.async {
                self.delegate.dataModelPersistenceStatus(changedTo: self.persistenceStatus)
            }
        }
    }
    var totalDays: Int {
        trips.reduce(0) { $0 + $1.days }
    }
    
    weak var delegate: DataModelDelegate!
    
    // MARK: - Initializer
    init(cloudKitManager: CloudKitManager, connectivityManager: ConnectivityManager) {
        self.connectivityManager = connectivityManager
        self.cloudKitManager = cloudKitManager
        
        self.cloudKitManager.delegate = self
        self.connectivityManager.delegate = self
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
        guard persistenceStatus != .unknown else {
            print("Persistence status was unknown. Did not load trips.")
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
        guard persistenceStatus != .unknown else {
            print("Persistence status was unknown. Did not save trips.")
            return
        }

        // If available, persist data in iCloud as source of truth across all iOS devices
        if persistenceStatus == .iCloudAvailable {
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

// MARK: - CloudKitManagerDelegate
extension DataModel: CloudKitManagerDelegate {
    func cloudKitManager(accountStatusDidUpdate accountStatus: CKAccountStatus) {
        // networkUnavailable state has priority over iCloud status
        if persistenceStatus != .networkUnavailable {
            persistenceStatus = cloudKitManager.accountStatus == .available ? .iCloudAvailable : .iCloudUnavailable
        }
    }
    
    func cloudKitManager(didHaveError error: Error) {
        guard let ckError = error as? CKError else { return }
        
        if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
            persistenceStatus = .networkUnavailable
            return
        }
        
        // TODO: Pass error back to delegate
    }
}

// MARK: - ConnectivityManagerDelegate
extension DataModel: ConnectivityManagerDelegate {
    func connectivityManagerStatusChanged(to status: NWPath.Status) {
        guard status == .satisfied else {
            print("Device is not connected to a network.")
            persistenceStatus = .networkUnavailable
            return
        }
        
        // Set status to unknown to trigger CKAccountStatus update
        persistenceStatus = .unknown
    }
}

// MARK: - PersistenceStatus
enum PersistenceStatus {
    case iCloudAvailable
    case iCloudUnavailable
    case networkUnavailable
    case unknown
}
