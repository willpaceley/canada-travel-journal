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
    func dataServicePersistenceStatus(changedTo status: PersistenceStatus)
    func dataService(didHaveSaveError error: TravelJournalError)
    func dataService(didHaveCloudKitError error: CKError)
}

class TripDataService {
    let connectivityManager: ConnectivityManager
    let cloudKitManager: CloudKitManager
    
    var persistenceStatus: PersistenceStatus = .unknown {
        didSet {
            DispatchQueue.main.async {
                self.delegate.dataServicePersistenceStatus(changedTo: self.persistenceStatus)
            }
        }
    }
    
    weak var delegate: TripDataServiceDelegate!
    
    // MARK: - Initializer
    init(cloudKitManager: CloudKitManager, connectivityManager: ConnectivityManager) {
        self.connectivityManager = connectivityManager
        self.cloudKitManager = cloudKitManager
        
        self.cloudKitManager.delegate = self
        self.connectivityManager.delegate = self
    }
    
    // MARK: - Data Persistence
    func loadTrips(completionHandler: @escaping (Result<[Trip]?, TravelJournalError>) -> Void) {
        guard persistenceStatus != .unknown else {
            logger.warning("Persistence status was unknown. Did not load trips.")
            completionHandler(.failure(TravelJournalError.unknownPersistenceStatus))
            return
        }
        
        let iCloudDataIsStale = UserDefaults.standard.bool(forKey: iCloudDataIsStaleKey)
        if iCloudDataIsStale {
            logger.warning("Trip data saved on device is more recent than iCloud record.")
        }
        
        if persistenceStatus == .iCloudAvailable && !iCloudDataIsStale {
            loadTripsFromiCloud(completionHandler: completionHandler)
        } else {
            loadTripsFromDevice(completionHandler: completionHandler)
        }
    }
    
    func save(_ trips: [Trip]) {
        guard persistenceStatus != .unknown else {
            logger.warning("Persistence status was unknown. Did not save trips.")
            return
        }
        
        guard !trips.isEmpty else {
            logger.warning("No trips available to save. Did not create empty record.")
            return
        }

        // If available, persist data in iCloud as source of truth across all iOS devices
        if persistenceStatus == .iCloudAvailable {
            saveTripsToiCloud(trips)
        } else {
            // Toggle flag in UserDefaults to indicate iCloud data is stale
            cloudKitManager.iCloudDataIsStale = true
            logger.warning("iCloud unavailable for persistence. Saving trip data to device.")
        }
        
        // Always persist data on-device in case CloudKit is permanently or temporarily unavailable
        saveTripsToDevice(trips)
    }
    
    // MARK: - Private Methods
    private func loadTripsFromiCloud(
        completionHandler: @escaping (Result<[Trip]?, TravelJournalError>) -> Void
    ) {
        cloudKitManager.fetchTrips { result in
            switch result {
            case .success(let trips):
                completionHandler(.success(trips))
            case .failure(let error):
                let loadError = TravelJournalError.loadError(error)
                completionHandler(.failure(loadError))
            }
        }
    }
    
    private func loadTripsFromDevice(
        completionHandler: @escaping (Result<[Trip]?, TravelJournalError>) -> Void
    ) {
        let fileManager = FileManager.default
        if fileManager.tripDataFileExists() {
            logger.log("Loading trips from on-device storage.")
            let url = fileManager.getTripDataURL()
            do {
                let tripData = try Data(contentsOf: url)
                let trips = try JSONDecoder().decode([Trip].self, from: tripData)
                logger.log("Trips successfully decoded from device storage.")
                completionHandler(.success(trips))
            } catch {
                logger.error("An error occured loading trips from device storage: \(error.localizedDescription)")
                let loadError = TravelJournalError.loadError(error)
                completionHandler(.failure(loadError))
            }
        }
    }
    
    private func saveTripsToiCloud(_ trips: [Trip]) {
        cloudKitManager.postTrips(trips: trips) { [weak self] result in
            switch result {
            case .success(_):
                logger.log("Trips successfully saved to CloudKit DB.")
                self?.cloudKitManager.iCloudDataIsStale = false
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
    
    private func saveTripsToDevice(_ trips: [Trip]) {
        let url = FileManager.default.getTripDataURL()
        do {
            let jsonData = try JSONEncoder().encode(trips)
            try jsonData.write(to: url, options: [.atomic])
            logger.log("Trip data successfully saved in the app's documents directory.")
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
