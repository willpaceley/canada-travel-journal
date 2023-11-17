//
//  CKAccountStatus+CustomStringConvertible.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-17.
//

import CloudKit

extension CKAccountStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .available:
            return "available"
        case .restricted:
            return "restricted"
        case .noAccount:
            return "noAccount"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown status type"
        }
    }
}
