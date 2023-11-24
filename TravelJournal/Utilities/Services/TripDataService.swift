//
//  TripDataService.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-05.
//

import CloudKit
import Network
import OSLog

fileprivate let logger = Logger(category: "TripDataService")

protocol TripDataServiceDelegate: AnyObject {
    func tripDataDidChange()
    func dataServiceDidLoadTrips()
    func dataServicePersistenceStatus(changedTo status: PersistenceStatus)
    func dataService(didHaveLoadError error: TravelJournalError)
    func dataService(didHaveSaveError error: TravelJournalError)
    func dataService(didHaveCloudKitError error: CKError)
}

class TripDataService {
    private(set) var trips = [Trip]()
    private var hasUnsavedChanges = false
    
    let connectivityManager: ConnectivityManager
    let cloudKitManager: CloudKitManager
    
    var persistenceStatus: PersistenceStatus = .unknown {
        didSet {
            DispatchQueue.main.async {
                self.delegate.dataServicePersistenceStatus(changedTo: self.persistenceStatus)
            }
        }
    }
    var totalDays: Int {
        trips.reduce(0) { $0 + $1.days }
    }
    
    weak var delegate: TripDataServiceDelegate!
    
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
        delegate.tripDataDidChange()
    }
    
    func updatedTrip() {
        hasUnsavedChanges = true
    }
    
    func delete(trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips.remove(at: index)
            hasUnsavedChanges = true
            delegate.tripDataDidChange()
        } else {
            logger.error("There was a problem finding the index of the trip to delete")
        }
    }
    
    // MARK: - Data Persistence
    func loadTrips() {
        guard persistenceStatus != .unknown else {
            logger.warning("Persistence status was unknown. Did not load trips.")
            delegate.dataService(didHaveLoadError: TravelJournalError.unknownPersistenceStatus)
            return
        }
        
        guard !hasUnsavedChanges else {
            logger.warning("There are unsaved changes. Did not load trips.")
            delegate.dataService(didHaveLoadError: TravelJournalError.unsavedChanges)
            return
        }
        
        let iCloudDataIsStale = UserDefaults.standard.bool(forKey: iCloudDataIsStaleKey)
        
        if persistenceStatus == .iCloudAvailable && !iCloudDataIsStale {
            loadTripsFromiCloud()
        } else {
            loadTripsFromDevice()
        }
    }
    
    func saveTrips() {
        guard persistenceStatus != .unknown else {
            logger.warning("Persistence status was unknown. Did not save trips.")
            return
        }
        
        // TODO: Add a guard for empty trips array to prevent persisting nothing

        // If available, persist data in iCloud as source of truth across all iOS devices
        if persistenceStatus == .iCloudAvailable {
            saveTripsToiCloud()
        } else {
            // Toggle flag in UserDefaults to indicate iCloud data is stale
            cloudKitManager.iCloudDataIsStale = true
        }
        
        // Always persist data on-device in case CloudKit is permanently or temporarily unavailable
        saveTripsToDevice()
    }
    
    // MARK: - Private Methods
    private func sortByReverseChronological() {
        trips.sort { $0.departureDate > $1.departureDate }
    }
    
    private func loadTripsFromiCloud() {
        cloudKitManager.fetchTrips { [weak self] result in
            switch result {
            case .success(let trips):
                if let trips {
                    self?.trips = trips
                }
                DispatchQueue.main.async {
                    self?.delegate.dataServiceDidLoadTrips()
                    self?.delegate.tripDataDidChange()
                }
                return
            case .failure(let error):
                let loadError = TravelJournalError.loadError(error)
                DispatchQueue.main.async {
                    self?.delegate.dataService(didHaveLoadError: loadError)
                }
            }
        }
    }
    
    private func loadTripsFromDevice() {
        let fileManager = FileManager.default
        if fileManager.tripDataFileExists() {
            logger.log("Loading trips from on-device storage.")
            let url = fileManager.getTripDataURL()
            do {
                let tripData = try Data(contentsOf: url)
                trips = try JSONDecoder().decode([Trip].self, from: tripData)
                logger.log("Trips successfully decoded from device storage.")
            } catch {
                logger.error("An error occured loading trips from device storage: \(error.localizedDescription)")
                let loadError = TravelJournalError.loadError(error)
                delegate.dataService(didHaveLoadError: loadError)
                return
            }
            delegate.dataServiceDidLoadTrips()
            delegate.tripDataDidChange()
        }
    }
    
    private func saveTripsToiCloud() {
        cloudKitManager.postTrips(trips: trips) { [weak self] result in
            switch result {
            case .success(_):
                logger.log("Trips successfully saved to CloudKit DB.")
                self?.cloudKitManager.iCloudDataIsStale = false
                self?.hasUnsavedChanges = false
            case .failure(let error):
                logger.error("An error occurred while attempting to save trips to CloudKit DB.")
                self?.cloudKitManager.iCloudDataIsStale = true
                let saveError = TravelJournalError.saveError(error)
                DispatchQueue.main.async {
                    self?.delegate.dataService(didHaveSaveError: saveError)
                }
            }
        }
    }
    
    private func saveTripsToDevice() {
        let url = FileManager.default.getTripDataURL()
        do {
            let jsonData = try JSONEncoder().encode(trips)
            try jsonData.write(to: url, options: [.atomic])
            logger.log("Trip data successfully saved in the app's documents directory.")
            hasUnsavedChanges = false
        } catch {
            logger.error("An error occurred saving trip data on device: \(error.localizedDescription)")
        }
    }
}

// MARK: - CloudKitManagerDelegate
extension TripDataService: CloudKitManagerDelegate {
    func cloudKitManager(accountStatusDidChange accountStatus: CKAccountStatus) {
        logger.debug("CloudKit account status changed to: \(accountStatus)")
        
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
        
        delegate.dataService(didHaveCloudKitError: ckError)
    }
}

// MARK: - ConnectivityManagerDelegate
extension TripDataService: ConnectivityManagerDelegate {
    func connectivityManagerStatusChanged(to status: NWPath.Status) {
        guard status == .satisfied else {
            logger.warning("Device is not connected to a network.")
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
