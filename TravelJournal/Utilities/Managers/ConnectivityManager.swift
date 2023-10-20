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
    weak var delegate: ConnectivityManagerDelegate!
    var status: NWPath.Status?
    
    init() {
        monitor.pathUpdateHandler = pathUpdateHandler(_:)
    }
    
    func startMonitor() {
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }
    
    private func pathUpdateHandler(_ path: NWPath) {
        // If the status has changed, call the delegate method
        if path.status != status {
            delegate.connectivityManagerStatusChanged(to: path.status)
        }
        status = path.status
    }
}
