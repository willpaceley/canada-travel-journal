//
//  CloudKitManager.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-08-08.
//
//  Portions of code authored by Bart Jacobs
//  From the article: https://cocoacasts.com/handling-account-status-changes-with-cloudkit

import CloudKit
import Network

protocol CloudKitManagerDelegate: AnyObject {
    func cloudKitManager(accountStatusChanged accountStatus: CKAccountStatus)
    func cloudKitManager(didHaveError error: Error)
}

class CloudKitManager {
    private let cloudKitDatabase = CKContainer.default().privateCloudDatabase
    private(set) var accountStatus: CKAccountStatus?
    private(set) var tripsRecordId: CKRecord.ID?
    
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
        requestAccountStatus()
        setupNotificationHandling()
    }
    
    // MARK: - Private Methods
    private func requestAccountStatus() {
        CKContainer.default().accountStatus { [unowned self] status, error in
            if let error {
                DispatchQueue.main.async {
                    self.delegate.cloudKitManager(didHaveError: error)
                }
                return
            }
            
            // Return if the CKAccountStatus hasn't changed
            guard self.accountStatus != status else {
                return
            }
            
            self.accountStatus = status
            DispatchQueue.main.async {
                self.delegate.cloudKitManager(accountStatusChanged: status)
            }
        }
    }
    
    private func setupNotificationHandling() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(accountDidChange(_:)),
            name: Notification.Name.CKAccountChanged,
            object: nil
        )
    }
    
    // MARK: - Notification Handling
    @objc func accountDidChange(_ notification: Notification) {
        print("accountDidChange notification received. Requesting updated CKAccountStatus.")
        DispatchQueue.main.async {
            self.requestAccountStatus()
        }
    }
    
    // MARK: - CloudKit Helper Methods
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
                            self?.tripsRecordId = record.recordID
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
        do {
            let tripData = try JSONEncoder().encode(trips)
            let tripsRecord = CKRecord(recordType: tripsRecordType)
            tripsRecord[tripDataKey] = tripData
            
            // If there is an existing trips record saved in CloudKit database
            if let tripsRecordId {
                print("Trips are already saved in CloudKit DB. Updating existing record.")
                cloudKitDatabase.modifyRecords(saving: [tripsRecord], deleting: [tripsRecordId]) {
                    [weak self] result in
                    switch result {
                    case .success((let saveResults, let deleteResults)):
                        // Confirm that the updated record was successfully saved to CloudKit
                        for (recordId, saveResult) in saveResults {
                            switch saveResult {
                            case .success(let record):
                                print("Successfully updated existing record trips record in CloudKit DB.")
                                self?.tripsRecordId = recordId
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
            } else {
                // Create new record if no previous trips record present in CloudKit
                print("No trips found in CloudKit DB. Creating new record.")
                cloudKitDatabase.save(tripsRecord) { [weak self] record, error in
                    if let error {
                        print("An error occurred creating new CloudKit trips record.")
                        completionHandler(.failure(error))
                        return
                    }
                    
                    if let record {
                        print("Successfully saved new trips record to CloudKit.")
                        self?.tripsRecordId = record.recordID
                        completionHandler(.success(record))
                    }
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }
}


