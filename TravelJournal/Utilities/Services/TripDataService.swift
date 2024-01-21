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
    func dataServicePersistenceStatusUpdated(to status: PersistenceStatus)
    func dataService(didHaveSaveError error: TravelJournalError)
    func dataService(didHaveCloudKitError error: CKError)
}

class TripDataService {
    let connectivityManager: ConnectivityManager
    let cloudKitManager: CloudKitManager
    
    var persistenceStatus: PersistenceStatus = .unknown {
        didSet {
            DispatchQueue.main.async {
                self.delegate.dataServicePersistenceStatusUpdated(to: self.persistenceStatus)
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
            
        if persistenceStatus == .iCloudAvailable {
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
            logger.warning("App has no trips, erasing all records in CK database.")
            cloudKitManager.deleteAllTripRecords()
            saveTripsToDevice(trips)
            return
        }

        // If available, persist data in iCloud as source of truth across all iOS devices
        if persistenceStatus == .iCloudAvailable {
            saveTripsToiCloud(trips)
        } else {
            logger.warning("iCloud unavailable for persistence. Saving trip data to device.")
        }
        
        saveTripsToDevice(trips)
    }
    
    // MARK: - Private Methods
    private func loadTripsFromiCloud(
        completionHandler: @escaping (Result<[Trip]?, TravelJournalError>) -> Void
    ) {
        cloudKitManager.fetchTrips { result in
            switch result {
            case .success(let trips):
                guard trips != nil else {
                    // If trips was nil, load trips from on-device storage
                    self.loadTripsFromDevice(completionHandler: completionHandler)
                    return
                }
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
        } else {
            logger.log("No trip data found in on-device storage.")
            completionHandler(.success(nil))
        }
    }
    
    private func saveTripsToiCloud(_ trips: [Trip]) {
        cloudKitManager.postTrips(trips: trips) { [weak self] result in
            switch result {
            case .success(_):
                logger.log("Trips successfully saved to CloudKit DB.")
            case .failure(let error):
                logger.error("An error occurred while attempting to save trips to CloudKit DB.")
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
            // Persist the Date we last modified the trip data to UserDefaults
            UserDefaults.standard.setValue(Date(), forKey: onDeviceDataLastModifiedKey)
            logger.log("Trip data successfully saved in the app's documents directory.")
        } catch {
            logger.error("An error occurred saving trip data on device: \(error.localizedDescription)")
        }
    }
}

// MARK: - CloudKitManagerDelegate
extension TripDataService: CloudKitManagerDelegate {
    func cloudKitManager(accountStatusDidUpdate accountStatus: CKAccountStatus) {
        logger.debug("CloudKit account status updated to: \(accountStatus, privacy: .public)")
        
        // networkUnavailable state has priority over iCloud status
        if persistenceStatus != .networkUnavailable {
            persistenceStatus = accountStatus == .available ? .iCloudAvailable : .iCloudUnavailable
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
