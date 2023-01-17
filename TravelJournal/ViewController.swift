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
    var totalDays: Int {
        return trips.reduce(0) { $0 + $1.days }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Canada Travel Journal"
        
        let addBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBarButtonPressed))
        navigationItem.rightBarButtonItems = [addBarButton]
        
        loadTrips()
        sortByReverseChronological()
        tableView.reloadData()
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        openTripDetailView(for: trips[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let ac = UIAlertController(title: "Delete Trip", message: "Are you sure you want to delete this trip?", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                self?.deleteTrip((self?.trips[indexPath.row])!)
            }))
            
            present(ac, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if !trips.isEmpty {
            return "Total days outside of Canada: \(totalDays)"
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if trips.isEmpty {
            return "Start tracking your trips outside of Canada by clicking the ＋ button in the top-right corner."
        }
        
        return nil
    }
    
    func reloadFooter() {
        tableView.beginUpdates()
        
        var contentConfig = tableView.footerView(forSection: 0)?.defaultContentConfiguration()
        contentConfig?.text = !trips.isEmpty ? "Total days outside of Canada: \(totalDays)" : nil
        tableView.footerView(forSection: 0)?.contentConfiguration = contentConfig
        
        tableView.endUpdates()
    }
    
    func format(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM. dd, yyyy"
        let formattedDate = dateFormatter.string(from: date)
        
        return formattedDate
    }
    
    func sortByReverseChronological() {
        trips.sort { $0.departureDate > $1.departureDate }
    }
    
    @objc func addBarButtonPressed() {
        openTripDetailView(for: nil)
    }
    
    func openTripDetailView(for trip: Trip?) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "TripEditor") as? TripEditorViewController {
            if let trip { vc.tripToEdit = trip }
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        } else {
            print("A problem occurred initializing TripEditorViewController")
        }
    }
    
    func addTrip(_ trip: Trip) {
        trips.append(trip)
        saveTrips()
        sortByReverseChronological()
        tableView.reloadData()
    }
    
    func deleteTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips.remove(at: index)
            
            let indexPath = IndexPath(row: index, section: 0)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            reloadFooter()
            
            saveTrips()
        } else {
            print("There was a problem finding the index of the trip to delete")
        }
    }
    
    func updateTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips[index] = trip
            
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
            reloadFooter()
            
            saveTrips()
        } else {
            print("There was a problem finding the index of the trip to update")
        }
    }
    
    // MARK: User Defaults
    func saveTrips() {
        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(trips) {
            let defaults = UserDefaults.standard
            defaults.set(encodedData, forKey: "travelJournalTrips")
        } else {
            print("There was a problem saving trips")
        }
    }
    
    func loadTrips() {
        let defaults = UserDefaults.standard
        
        if let savedTrips = defaults.object(forKey: "travelJournalTrips") as? Data {
            let decoder = JSONDecoder()
            do {
                try trips = decoder.decode([Trip].self, from: savedTrips)
            } catch {
                print("An error occurred decoding the trip data")
            }
        }
    }
}

