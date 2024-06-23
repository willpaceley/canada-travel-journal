//
//  TripDatabase.swift
//  TravelJournal
//
//  Created by Will Paceley on 2024-06-23.
//

import Foundation
import CloudKit

protocol TripDatabase {
    @preconcurrency
    func fetch(
        withQuery query: CKQuery,
        inZoneWith zoneID: CKRecordZone.ID?,
        desiredKeys: [CKRecord.FieldKey]?,
        resultsLimit: Int,
        completionHandler: @escaping @Sendable (Result<(matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?), any Error>) -> Void
    )
    @preconcurrency
    func modifyRecords(
        saving recordsToSave: [CKRecord],
        deleting recordIDsToDelete: [CKRecord.ID],
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy,
        atomically: Bool,
        completionHandler: @escaping @Sendable (Result<(saveResults: [CKRecord.ID : Result<CKRecord, any Error>], deleteResults: [CKRecord.ID : Result<Void, any Error>]), any Error>) -> Void
    )
    func save(
        _ record: CKRecord,
        completionHandler: @escaping @Sendable (CKRecord?, (any Error)?) -> Void
    )
    func delete(
        withRecordID recordID: CKRecord.ID,
        completionHandler: @escaping @Sendable (CKRecord.ID?, (any Error)?) -> Void
    )
}

extension CKDatabase: TripDatabase {}
