//
//  ErrorAlertFactory.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-09.
//

import CloudKit

typealias Alert = (title: String, message: String)

struct ErrorAlertFactory {
    // MARK: - loadError
    static func loadErrorAlert(for error: Error) -> Alert {
        let alert: Alert
        
        // CKError
        if let ckError = error as? CKError {
            alert = (
                title: "iCloud Load Error",
                message: "\(error.localizedDescription). Error Code: \(ckError.code.rawValue)"
            )
            return alert
        }
        
        // DecodingError
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .typeMismatch:
                alert = (
                    title: "Type Mismatch",
                    message: "The trip data could not be decoded because it did not match the type of what was found in the encoded payload."
                )
            case .valueNotFound:
                alert = (
                    title: "Value Not Found",
                    message: "A non-optional value of the given type was expected, but a null value was found."
                )
            case .keyNotFound(let codingKey, _):
                alert = (
                    title: "Key Not Found",
                    message: "A keyed decoding container was asked for an entry for the given key, \(codingKey.stringValue), but did not contain one."
                )
            case .dataCorrupted:
                alert = (
                    title: "Data Corrupted",
                    message: "The trip data is corrupted or otherwise invalid and could not be decoded."
                )
            @unknown default:
                alert = (
                    title: "Decoding Error",
                    message: "An error of unknown origin occurred while decoding trip data from JSON."
                )
            }
            return alert
        }
        
        alert = (title: "Loading Error", message: error.localizedDescription)
        return alert
    }
    
    // MARK: - saveError
    static func saveErrorAlert(for error: Error) -> Alert {
        let alert: Alert
        
        // CKError
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable:
                alert = (
                    title: "Network Unavailable",
                    message: "Your device's internet connection appears to be offline. Your trip data is being saved to your device and will synchronize with CloudKit in the future."
                )
            case .notAuthenticated:
                alert = (
                    title: "iCloud Drive Not Enabled",
                    message: "Please turn on iCloud Drive in the Settings for your device. While iCloud is unavaiable, your trips will be saved to your device."
                )
            default:
                alert = (
                    title: "iCloud Save Error",
                    message: "\(error.localizedDescription). Error Code: \(ckError.code.rawValue)"
                )
            }
            return alert
        }
        
        // EncodingError
        if let encodingError = error as? EncodingError {
            switch encodingError {
            case .invalidValue(_, let context):
                alert = (
                    title: "Encoding Error",
                    message: "An error occurred encoding trip data into JSON. \(context.debugDescription)"
                )
            @unknown default:
                alert = (
                    title: "Encoding Error",
                    message: "An error of unknown origin occurred while encoding trip data into JSON."
                )
            }
            return alert
        }
        
        alert = (title: "Save Error", message: error.localizedDescription)
        return alert
    }
}

// MARK: - TravelJournalError
enum TravelJournalError: Error, Equatable {
    case loadError(_ error: Error)
    case saveError(_ error: Error)
    case cloudKitError(_ error: CKError)
    case unknownPersistenceStatus
    case unsavedChanges
    
    // Necessary implementation for conformance to Equatable
    static func == (lhs: TravelJournalError, rhs: TravelJournalError) -> Bool {
        switch (lhs, rhs) {
        case let (.loadError(error1), .loadError(error2)):
            return error1.localizedDescription == error2.localizedDescription
        case let (.saveError(error1), .saveError(error2)):
            return error1.localizedDescription == error2.localizedDescription
        case let (.cloudKitError(error1), .cloudKitError(error2)):
            return error1.localizedDescription == error2.localizedDescription
        case (.unknownPersistenceStatus, .unknownPersistenceStatus),
            (.unsavedChanges, .unsavedChanges):
            return true
        default:
            return false
        }
    }
}
