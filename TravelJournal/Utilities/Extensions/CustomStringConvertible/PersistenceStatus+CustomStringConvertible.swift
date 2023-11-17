//
//  PersistenceStatus+CustomStringConvertible.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-17.
//

extension PersistenceStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .iCloudAvailable:
            return "iCloudAvailable"
        case .iCloudUnavailable:
            return "iCloudUnavailable"
        case .networkUnavailable:
            return "networkUnavailable"
        case .unknown:
            return "unknown"
        }
    }
}
