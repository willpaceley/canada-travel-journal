//
//  ViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import UIKit

class ViewController: UITableViewController {
    var trips = [Trip]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let newTrip = Trip(departureDate: Date(timeIntervalSinceNow: 1), returnDate: Date(timeIntervalSinceNow: 2), destination: "USA", reason: "Shopping")
        trips.append(newTrip)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(openTripEditor))
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trips.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Trip", for: indexPath)
        let trip = trips[indexPath.row]
        
        cell.textLabel?.text = trip.destination
        cell.detailTextLabel?.text = trip.reason
        
        return cell
    }
    
    @objc func openTripEditor() {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "TripEditor") as? TripEditorViewController {
            vc.isNewTrip = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

