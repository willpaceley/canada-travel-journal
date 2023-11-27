//
//  CloudKitManager.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-08-08.
//
//  Portions of code authored by Bart Jacobs
//  From the article: https://cocoacasts.com/handling-account-status-changes-with-cloudkit

import CloudKit
import OSLog

fileprivate let logger = Logger(category: "CloudKitManager")

protocol CloudKitManagerDelegate: AnyObject {
    func cloudKitManager(accountStatusDidChange accountStatus: CKAccountStatus)
    func cloudKitManager(didHaveError error: Error)
}

class CloudKitManager {
    private let cloudKitDatabase = CKContainer.default().privateCloudDatabase
    private let tripsQuery = CKQuery(
        recordType: tripsRecordType,
        predicate: NSPredicate(value: true)
    )
    
    private(set) var accountStatus: CKAccountStatus?
    private(set) var tripsRecordID: CKRecord.ID?
    private(set) var checkedForExistingRecord = false
    
    weak var delegate: CloudKitManagerDelegate!
    
    var iCloudDataIsStale: Bool {
        get {
            UserDefaults.standard.bool(forKey: iCloudDataIsStaleKey)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: iCloudDataIsStaleKey)
        }
    }
    
    init() {
        setupNotificationHandling()
    }
    
    // MARK: - Notification Handling
    private func setupNotificationHandling() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(accountDidChange(_:)),
            name: Notification.Name.CKAccountChanged,
            object: nil
        )
    }
    
    @objc func accountDidChange(_ notification: Notification) {
        logger.log("accountDidChange notification received. Requesting updated CKAccountStatus.")
        // TODO: Consider setting a flag to prevent re-requesting while a request is in progress
        DispatchQueue.main.async {
            self.requestAccountStatus()
        }
    }
    
    // MARK: - CloudKit Helper Methods
    func requestAccountStatus() {
        CKContainer.default().accountStatus { [weak self] status, error in
            guard let self else { return }
            
            if let error {
                DispatchQueue.main.async {
                    self.delegate.cloudKitManager(didHaveError: error)
                }
                return
            }
            
            // Check if the account status has changed
            if status != self.accountStatus {
                self.accountStatus = status
                DispatchQueue.main.async {
                    self.delegate.cloudKitManager(accountStatusDidChange: status)
                }
            }
        }
    }
    
    func fetchTrips(completionHandler: @escaping (Result<[Trip]?, Error>) -> Void) {
        logger.log("Attempting to fetch trip data from CloudKit.")
        cloudKitDatabase.fetch(withQuery: tripsQuery, resultsLimit: 1) { [weak self] result in
            switch result {
            case .success((let matchResults, _)):
                if matchResults.isEmpty {
                    logger.log("No Trips record found in CloudKit DB.")
                    completionHandler(.success(nil))
                    return
                }
                
                let (_, matchResult) = matchResults.first!
                switch matchResult {
                case .success(let record):
                    logger.log("Found a pre-existing trips record ID: \(record.recordID.recordName)")
                    // Set the record ID to update later without re-fetching
                    self?.tripsRecordID = record.recordID
                    self?.checkedForExistingRecord = true
                    
                    if let tripData = record.value(forKey: tripDataKey) as? Data,
                       let trips = try? JSONDecoder().decode([Trip].self, from: tripData) {
                        logger.log("Successfully decoded trips from CloudKit database.")
                        completionHandler(.success(trips))
                        return
                    }
                    
                case .failure(let error):
                    completionHandler(.failure(error))
                    return
                }
                
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    func postTrips(trips: [Trip], completionHandler: @escaping (Result<CKRecord, Error>) -> Void) {
        // Only proceed if there is a pre-existing CKRecord.ID for the trip data
        guard let tripsRecordID else {
            if checkedForExistingRecord {
                logger.log("No trips found in CloudKit DB. Creating new record.")
                createNewTripsRecord(trips: trips, completionHandler: completionHandler)
            } else {
                logger.log("Checking for a pre-existing trips record ID in CloudKit DB.")
                checkForTripsRecordID(trips: trips, completionHandler: completionHandler)
            }
            return
        }
        
        // There is an existing trips record saved in CloudKit database
        logger.log("Trips are already saved in CloudKit DB. Updating existing record.")
        do {
            let tripsRecord = CKRecord(recordType: tripsRecordType)
            let tripData = try JSONEncoder().encode(trips)
            tripsRecord[tripDataKey] = tripData
            
            cloudKitDatabase.modifyRecords(saving: [tripsRecord], deleting: [tripsRecordID]) {
                [weak self] result in
                switch result {
                case .success((let saveResults, let deleteResults)):
                    // Confirm that the updated record was successfully saved to CloudKit
                    for (recordId, saveResult) in saveResults {
                        switch saveResult {
                        case .success(let record):
                            logger.log("Successfully updated existing record trips record in CloudKit DB.")
                            self?.tripsRecordID = recordId
                            self?.checkedForExistingRecord = true
                            completionHandler(.success(record))
                        case .failure(let error):
                            logger.error("An error occurred updating a trips record in CloudKit DB.")
                            completionHandler(.failure(error))
                        }
                    }
                    
                    // Confirm that the old record was successfully deleted from CloudKit
                    for (recordId, deleteResult) in deleteResults {
                        switch deleteResult {
                        case .success():
                            logger.log("Old Trips record successfully deleted from CloudKit: \(recordId.recordName)")
                        case.failure(let error):
                            completionHandler(.failure(error))
                        }
                    }
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    /// Deletes all trip data from the user's private iCloud Database.
    ///
    /// > Warning: This method is for development purposes only.
    /// Usage in production could result in an irrecoverable loss of the user's trip data.
    func deleteAllTripRecords() {
        cloudKitDatabase.fetch(withQuery: tripsQuery) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let (matchResults, _)):
                for (recordID, _) in matchResults {
                    self.cloudKitDatabase.delete(withRecordID: recordID) { deletedRecordID, deleteError in
                        if let error = deleteError {
                            logger.error("An error occurred deleting CKRecord. \(error.localizedDescription)")
                        }
                        
                        if let recordID = deletedRecordID {
                            logger.log("Deleted record with ID: \(recordID.recordName)")
                        }
                    }
                }
                
            case .failure(let error):
                logger.error("An error occurred while fetching records to delete. \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func createNewTripsRecord(trips: [Trip], completionHandler: @escaping (Result<CKRecord, Error>) -> Void) {
        let tripsRecord = CKRecord(recordType: tripsRecordType)
        
        cloudKitDatabase.save(tripsRecord) { [weak self] record, error in
            if let error {
                logger.error("An error occurred creating new CloudKit trips record.")
                completionHandler(.failure(error))
                return
            }
            
            if let record {
                logger.log("Successfully saved new trips record to CloudKit.")
                self?.tripsRecordID = record.recordID
                self?.checkedForExistingRecord = true
                completionHandler(.success(record))
            }
        }
    }
    
    /// Checks the CloudKit private database for a pre-existing `CKRecord.ID` and passes the parameters
    /// back to ``postTrips(trips:completionHandler:)`` to save the user's trip data in iCloud.
    ///
    /// This method is necessary to prevent an edge case that results in the accidental creation
    /// of a second record in the CloudKit private database. This edge case can occur when the app
    /// doesn't fetch trips from iCloud on launch (e.g. iCloud is initially unavailable or iCloud data is marked stale).
    private func checkForTripsRecordID(
        trips: [Trip],
        completionHandler: @escaping ((Result<CKRecord, Error>) -> Void)
    ) {
        cloudKitDatabase.fetch(withQuery: tripsQuery, resultsLimit: 1) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let (matchResults, _)):
                if !matchResults.isEmpty {
                    let (recordID, _) = matchResults.first!
                    logger.log("Found a pre-existing trips record ID: \(recordID.recordName)")
                    self.tripsRecordID = recordID
                }
                
                self.checkedForExistingRecord = true
                postTrips(trips: trips, completionHandler: completionHandler)
                
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}


