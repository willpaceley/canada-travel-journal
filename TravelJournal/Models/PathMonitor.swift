//
//  PathMonitor.swift
//  TravelJournal
//
//  Created by Will Paceley on 2024-07-06.
//

import Network

protocol PathMonitor {
    func start(queue: DispatchQueue)
    var pathUpdateHandler: (@Sendable (_ newPath: NWPath) -> Void)? { get set }
}

extension NWPathMonitor: PathMonitor {}
