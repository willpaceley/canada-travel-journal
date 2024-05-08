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
    func cloudKitManager(accountStatusDidUpdate accountStatus: CKAccountStatus)
    func cloudKitManager(didHaveError error: Error)
}

class CloudKitManager {
    private let cloudKitDatabase = CKContainer.default().privateCloudDatabase
    private let tripsQuery = CKQuery(
        recordType: tripsRecordType,
        predicate: NSPredicate(value: true)
    )
    
    private(set) var cloudKitTripDataLastModified: Date?
    private(set) var requestInProgress = false
    
    weak var delegate: CloudKitManagerDelegate!
    
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
        logger.log("accountDidChange notification received.")
        
        guard !requestInProgress else {
            logger.warning("A request for CKAccountStatus was already in progress.")
            return
        }
        
        logger.log("Requesting updated CKAccountStatus.")
        DispatchQueue.main.async {
            self.requestAccountStatus()
        }
        
    }
    
    // MARK: - CloudKit Helper Methods
    func requestAccountStatus() {
        requestInProgress = true
        CKContainer.default().accountStatus { [weak self] status, error in
            guard let self else { return }
            self.requestInProgress = false
            
            if let error {
                logger.error("An error occurred requesting the CKAccountStatus. \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.delegate.cloudKitManager(didHaveError: error)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.delegate.cloudKitManager(accountStatusDidUpdate: status)
            }
        }
    }
    
    func fetchTrips(completionHandler: @escaping (Result<[Trip]?, Error>) -> Void) {
        logger.log("Attempting to fetch trip data from CloudKit.")
        cloudKitDatabase.fetch(withQuery: tripsQuery) { result in
            switch result {
            case .success((let matchResults, _)):
                if matchResults.isEmpty {
                    logger.log("No Trips record found in CloudKit DB.")
                    completionHandler(.success(nil))
                    return
                }
                
                // Find the record that was most recently modified
                var mostRecentRecord: CKRecord?
                for (_, matchResult) in matchResults {
                    switch matchResult {
                    case .success(let record):
                        let id = record.recordID.recordName
                        logger.debug("CloudKit trip data \(id) last modified on \(record.modificationDate!.formatted())")
                        
                        guard matchResults.count > 1 else {
                            logger.debug("There is only one trip record saved in CloudKit.")
                            mostRecentRecord = record
                            break
                        }
                        
                        // Check if the current record is the most recent thus far
                        mostRecentRecord = self.findMostRecentRecord(
                            previousRecord: mostRecentRecord,
                            currentRecord: record
                        )
                        
                    case .failure(let error):
                        completionHandler(.failure(error))
                        return
                    }
                }
                
                if let mostRecentRecord {
                    let id = mostRecentRecord.recordID.recordName
                    logger.debug("The trip record \(id) was the most recent CKRecord.")
                    
                    if let cloudKitTripDataLastModified = mostRecentRecord.modificationDate {
                        self.cloudKitTripDataLastModified = cloudKitTripDataLastModified
                        
                        let onDeviceTripDataLastModified = UserDefaults.standard.object(
                            forKey: onDeviceDataLastModifiedKey
                        ) as? Date ?? Date.distantPast
                        logger.debug("On device trip data last modified on \(onDeviceTripDataLastModified.formatted())")
                        
                        if onDeviceTripDataLastModified > cloudKitTripDataLastModified {
                            logger.log("On device trip data is more recent than the CKRecord.")
                            // Send a nil record back from completion handler to invoke loading local data
                            completionHandler(.success(nil))
                            return
                        }
                    }
                    
                    
                    logger.log("Decoding the most recent trip record from CloudKit.")
                    if let tripData = mostRecentRecord.value(forKey: tripDataKey) as? Data,
                       let trips = try? JSONDecoder().decode([Trip].self, from: tripData) {
                        logger.log("Successfully decoded trips from CloudKit database.")
                        
                        // If somehow an empty trip record is saved in CloudKit, delete it
                        if trips.isEmpty {
                            logger.log("Found an empty trip record saved in CloudKit.")
                            self.deleteTripRecord(withID: mostRecentRecord.recordID)
                        }
                        
                        // Delete any extraneous outdated trip records
                        if matchResults.count > 1 {
                            self.deleteAllTripRecords(excluding: mostRecentRecord.recordID)
                        }
                        
                        completionHandler(.success(trips))
                        return
                    } else {
                        logger.error("An error occurred decoding trip data from the CloudKit record.")
                    }
                }
                
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    func postTrips(trips: [Trip], completionHandler: @escaping (Result<CKRecord, Error>) -> Void) {
        logger.log("Checking for a pre-existing trips record ID in CloudKit DB.")
        cloudKitDatabase.fetch(withQuery: tripsQuery, resultsLimit: 1) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let (matchResults, _)):
                if !matchResults.isEmpty {
                    let (recordID, _) = matchResults.first!
                    logger.log("Found a pre-existing trips record ID: \(recordID.recordName)")
                    logger.log("Trips are already saved in CloudKit DB. Updating existing record.")
                    updateExistingTripsRecord(
                        trips: trips,
                        tripsRecordID: recordID,
                        completionHandler: completionHandler
                    )
                    return
                }
                logger.log("No trips found in CloudKit DB. Creating new record.")
                createNewTripsRecord(trips: trips, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    /// Deletes trip data from the user's private iCloud Database.
    ///
    /// - Parameters:
    ///     - idToKeep: The ID of a trip record to skip deleting from the database.
    ///     The most common use case is to keep the most up-to-date record.
    ///
    /// > Warning: Invoking this method results in an irrecoverable loss of trip data
    /// stored in the user's CloudKit database.
    func deleteAllTripRecords(excluding idToKeep: CKRecord.ID? = nil) {
        cloudKitDatabase.fetch(withQuery: tripsQuery) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let (matchResults, _)):
                for (recordID, _) in matchResults {
                    // Prevent deletion of the most recent record
                    if let idToKeep, recordID == idToKeep {
                        logger.debug("Skipped deleting record with ID \(recordID.recordName)")
                        continue
                    }
                    
                    deleteTripRecord(withID: recordID)
                }
                
            case .failure(let error):
                logger.error("An error occurred while fetching records to delete. \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func createNewTripsRecord(trips: [Trip], completionHandler: @escaping (Result<CKRecord, Error>) -> Void) {
        do {
            let tripsRecord = CKRecord(recordType: tripsRecordType)
            let tripData = try JSONEncoder().encode(trips)
            tripsRecord[tripDataKey] = tripData
            
            cloudKitDatabase.save(tripsRecord) { record, error in
                if let error {
                    logger.error("An error occurred creating new CloudKit trips record.")
                    completionHandler(.failure(error))
                    return
                }
                
                if let record {
                    logger.log("Successfully created new trips record in CloudKit.")
                    completionHandler(.success(record))
                }
            }
        } catch {
            logger.error("An error occurred encoding trip data to save in CloudKit.")
            completionHandler(.failure(error))
        }
    }
    
    private func updateExistingTripsRecord(
        trips: [Trip],
        tripsRecordID: CKRecord.ID,
        completionHandler: @escaping (Result<CKRecord, Error>) -> Void
    ) {
        do {
            let tripsRecord = CKRecord(recordType: tripsRecordType)
            let tripData = try JSONEncoder().encode(trips)
            tripsRecord[tripDataKey] = tripData
            
            cloudKitDatabase.modifyRecords(saving: [tripsRecord], deleting: [tripsRecordID]) { result in
                switch result {
                case .success((let saveResults, let deleteResults)):
                    // Confirm that the updated record was successfully saved to CloudKit
                    for (_, saveResult) in saveResults {
                        switch saveResult {
                        case .success(let record):
                            logger.log("Successfully updated existing record trips record in CloudKit DB.")
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
    
    private func deleteTripRecord(withID id: CKRecord.ID) {
        cloudKitDatabase.delete(withRecordID: id) { deletedRecordID, deleteError in
            if let error = deleteError {
                logger.error("An error occurred deleting CKRecord. \(error.localizedDescription)")
            }
            
            if let recordID = deletedRecordID {
                logger.debug("Deleted record with ID: \(recordID.recordName)")
            }
        }
    }
    
    private func findMostRecentRecord(previousRecord: CKRecord?, currentRecord: CKRecord) -> CKRecord {
        // Only do the comparison if there is a previous record to compare against
        if let previousRecord {
            if let currentDate = currentRecord.modificationDate,
               let previousDate = previousRecord.modificationDate {
                return currentDate > previousDate ? currentRecord : previousRecord
            }
        }
        return currentRecord
    }
}


