//
//  ErrorAlertFactory.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-09.
//

import CloudKit

typealias Alert = (title: String, message: String)

struct ErrorAlertFactory {
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
enum TravelJournalError: Error {
    case loadError(_ error: Error)
    case saveError(_ error: Error)
    case cloudKitError(_ error: CKError)
}
