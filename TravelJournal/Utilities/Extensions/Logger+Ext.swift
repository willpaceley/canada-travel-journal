//
//  Logger+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-17.
//

import OSLog

extension Logger {
    /// Helper initializer that uses the app's bundle identifier as the subsystem by default.
    init(category: String) {
        self.init(subsystem: "com.willpaceley.TravelJournal", category: category)
    }
}
