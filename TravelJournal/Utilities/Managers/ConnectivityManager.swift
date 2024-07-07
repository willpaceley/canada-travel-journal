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
    
    private var monitor: PathMonitor
    private(set) var status: NWPath.Status?
    
    weak var delegate: ConnectivityManagerDelegate!
    
    init(monitor: PathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.monitor.pathUpdateHandler = pathUpdateHandler(_:)
    }
    
    // Call startMonitor() after the TripDataService delegate has been set
    func startMonitor() {
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }
    
    private func connectivityUpdated(_ path: NWPath) {
        // If the status has changed, call the delegated method
        if path.status != status {
            delegate.connectivityManagerStatusChanged(to: path.status)
        }
        status = path.status
    }
    
    @Sendable
    private func pathUpdateHandler(_ path: NWPath) {
        connectivityUpdated(path)
    }
}
