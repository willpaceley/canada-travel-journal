//
//  Logger+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-11-17.
//

import OSLog

extension Logger {
    init(category: String) {
        self.init(subsystem: "com.willpaceley.TravelJournal", category: category)
    }
}
