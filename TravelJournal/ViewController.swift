//
//  ViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import Foundation
import UIKit

class ViewController: UITableViewController {
    var trips = [Trip]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Canada Travel Journal"
        
        let newTrip = Trip(departureDate: Date(timeIntervalSinceNow: 1), returnDate: Date(timeIntervalSinceNow: 2), destination: "United States", reason: "Shopping")
        trips.append(newTrip)
        
        let addBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(openAddTripView))
        navigationItem.rightBarButtonItems = [addBarButton]
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trips.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Trip", for: indexPath) as! TripViewCell
        let trip = trips[indexPath.row]
        
        cell.countryLabel.text = trip.destination
        cell.dateLabel.text = format(date: trip.departureDate)
        cell.daysLabel.text = "\(trip.days) \(trip.days > 1 ? "Days" : "Day")"
        
        return cell
    }
    
    func format(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM. dd, yyyy"
        let formattedDate = dateFormatter.string(from: date)
        
        return formattedDate
    }
    
    @objc func openAddTripView() {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "TripEditor") as? TripEditorViewController {
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func addTrip(_ trip: Trip) {
        trips.append(trip)
        tableView.reloadData()
    }
}

