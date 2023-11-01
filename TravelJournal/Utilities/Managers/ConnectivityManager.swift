//
//  ConnectivityManager.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-10-20.
//

import Network

protocol ConnectivityManagerDelegate: AnyObject {
    func connectivityManagerStatusChanged(to status: NWPath.Status)
}

class ConnectivityManager {
    private let monitor = NWPathMonitor()
    private var status: NWPath.Status?
    
    weak var delegate: ConnectivityManagerDelegate!
    
    init() {
        monitor.pathUpdateHandler = pathUpdateHandler(_:)
    }
    
    // Call startMonitor() after the DataModel delegate has been set
    func startMonitor() {
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }
    
    private func pathUpdateHandler(_ path: NWPath) {
        // If the status has changed, call the delegated method
        if path.status != status {
            delegate.connectivityManagerStatusChanged(to: path.status)
        }
        status = path.status
    }
}
