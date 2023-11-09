//
//  PersistenceAlertFactory.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-05.
//

import Foundation

struct PersistenceAlertFactory {
    static func alert(for persistenceStatus: PersistenceStatus) -> Alert {
        let title: String
        var message = ""
        
        switch persistenceStatus {
        case .iCloudAvailable:
            title = "Connected To iCloud"
            message = "Your trip data is securely stored in a private iCloud database. You can access and update your trip data across all of your iOS devices."
        case .iCloudUnavailable:
            title = "iCloud Unavailable"
            message += """
                        To fix this issue, ensure iCloud Drive is enabled in Settings. Please see instructions below.
                        
                        Step 1: Apple ID → iCloud → iCloud Drive → Sync this iPhone (On)
                        
                        Step 2: Apple ID → iCloud → Show All Apps Using iCloud → Travel Journal (On)
                        """
        case .networkUnavailable:
            title = "Network Unavailable"
            message = "Your device appears to be offline. Please check your internet connection."
        case .unknown:
            title = "Unknown Status"
            message += "Travel Journal is currently in an unexpected state. Please force close the application and relaunch to continue."
        }
        
        if persistenceStatus != .iCloudAvailable {
            message += "\n\nYour trips are being saved on your device. CAUTION: Deletion of this app will result in the permanent loss of your trip data."
        }
        
        return (title, message)
    }
}
