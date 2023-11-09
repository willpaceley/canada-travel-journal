//
//  ErrorAlertFactory.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-09.
//

import CloudKit

typealias Alert = (title: String, message: String)

struct ErrorAlertFactory {
    static func alert(for error: TravelJournalError) -> Alert {
        let title: String = ""
        let message: String = ""
        
        return (title, message)
    }
}

// MARK: - TravelJournalError
enum TravelJournalError: Error {
    case loadError(_ error: Error)
    case saveError(_ error: Error)
    case cloudKitError(_ error: CKError)
}
