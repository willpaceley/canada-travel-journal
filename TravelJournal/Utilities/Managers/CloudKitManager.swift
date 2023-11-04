//
//  CloudKitManager.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-08-08.
//
//  Portions of code authored by Bart Jacobs
//  From the article: https://cocoacasts.com/handling-account-status-changes-with-cloudkit

import CloudKit

protocol CloudKitManagerDelegate: AnyObject {
    func cloudKitManager(accountStatusDidUpdate accountStatus: CKAccountStatus)
    func cloudKitManager(didHaveError error: Error)
}

class CloudKitManager {
    private let cloudKitDatabase = CKContainer.default().privateCloudDatabase
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
        print("accountDidChange notification received. Requesting updated CKAccountStatus.")
        DispatchQueue.main.async {
            self.requestAccountStatus()
        }
    }
    
    // MARK: - CloudKit Helper Methods
    func requestAccountStatus() {
        CKContainer.default().accountStatus { [unowned self] status, error in
            if let error {
                DispatchQueue.main.async {
                    self.delegate.cloudKitManager(didHaveError: error)
                }
                return
            }
            
            self.accountStatus = status
            DispatchQueue.main.async {
                self.delegate.cloudKitManager(accountStatusDidUpdate: status)
            }
        }
    }
    
    func fetchTrips(
        forceDelete: Bool = false,
        completionHandler: @escaping (Result<[Trip]?, Error>) -> Void
    ) {
        let query = CKQuery(
            recordType: tripsRecordType,
            predicate: NSPredicate(value: true)
        )
        
        cloudKitDatabase.fetch(withQuery: query) { [weak self] result in
            switch result {
            case .success((let matchResults, _)):
                if matchResults.isEmpty {
                    print("No Trips record found in CloudKit DB.")
                    completionHandler(.success(nil))
                    return
                }
                
                for (_, matchResult) in matchResults {
                    switch matchResult {
                    case .success(let record):
                        // FOR DEVELOPMENT PURPOSES ONLY
                        // Set forceDelete flag to true to remove all Trip records
                        // Useful for debug purposes when multiple records were created
                        if forceDelete {
                            self?.cloudKitDatabase.delete(withRecordID: record.recordID) { (recordId, error) in
                                if let recordId {
                                    print("Deleted record with ID: \(recordId)")
                                }
                            }
                        } else {
                            // Set the record ID to update later without re-fetching
                            self?.tripsRecordID = record.recordID
                            self?.checkedForExistingRecord = true
                            
                            if let data = record.value(forKey: tripDataKey) as? Data {
                                if let trips = try? JSONDecoder().decode([Trip].self, from: data) {
                                    print("Successfully decoded trips from CK database, calling handler.")
                                    completionHandler(.success(trips))
                                    return
                                }
                            }
                        }
                        
                    case .failure(let error):
                        completionHandler(.failure(error))
                        return
                    }
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
                // If we checked for a record and it didn't exist, create a new one
                print("No trips found in CloudKit DB. Creating new record.")
                createNewTripsRecord(trips: trips, completionHandler: completionHandler)
            } else {
                // Check for a pre-existing CKRecord.ID before creating a new record
                print("Checking for a pre-existing trips record ID in CloudKit DB.")
                checkForTripsRecordID(trips: trips, completionHandler: completionHandler)
            }
            return
        }
        
        // There is an existing trips record saved in CloudKit database
        print("Trips are already saved in CloudKit DB. Updating existing record.")
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
                            print("Successfully updated existing record trips record in CloudKit DB.")
                            self?.tripsRecordID = recordId
                            self?.checkedForExistingRecord = true
                            completionHandler(.success(record))
                        case .failure(let error):
                            print("An error occurred updating a trips record in CloudKit DB.")
                            completionHandler(.failure(error))
                        }
                    }
                    
                    // Confirm that the old record was successfully deleted from CloudKit
                    for (recordId, deleteResult) in deleteResults {
                        switch deleteResult {
                        case .success():
                            print("Old Trips record successfully deleted from CloudKit: \(recordId.recordName)")
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
    
    // MARK: - Private Methods
    private func createNewTripsRecord(trips: [Trip], completionHandler: @escaping (Result<CKRecord, Error>) -> Void) {
        let tripsRecord = CKRecord(recordType: tripsRecordType)
        
        cloudKitDatabase.save(tripsRecord) { [weak self] record, error in
            if let error {
                print("An error occurred creating new CloudKit trips record.")
                completionHandler(.failure(error))
                return
            }
            
            if let record {
                print("Successfully saved new trips record to CloudKit.")
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
    private func checkForTripsRecordID(trips: [Trip], completionHandler: @escaping ((Result<CKRecord, Error>) -> Void)) {
        let query = CKQuery(
            recordType: tripsRecordType,
            predicate: NSPredicate(value: true)
        )
        
        cloudKitDatabase.fetch(withQuery: query, resultsLimit: 1) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let (matchResults, _)):
                if !matchResults.isEmpty {
                    let (recordID, _) = matchResults.first!
                    print("Found a pre-existing trips record ID: \(recordID.recordName)")
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


