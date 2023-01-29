//
//  ViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import Foundation
import UIKit
import MessageUI
import CloudKit

class ViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    
    var userLoggedInToiCloud = false
    var trips = [Trip]()
    var totalDays: Int {
        return trips.reduce(0) { $0 + $1.days }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        getiCloudStatus()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Canada Travel Journal"
        
        let addBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBarButtonPressed))
        navigationItem.rightBarButtonItem = addBarButton
        
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareBarButtonPressed))
        navigationItem.leftBarButtonItem = shareButton
        
        loadTrips()
        sortByReverseChronological()
        tableView.reloadData()
    }
    
    // TODO: Make an extension with all of the delegated methods (overriden)
    // Google "how to put delegated methods into an extension swift"
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
        return trips.isEmpty ? "Click the ＋ button to add a new trip!" : nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            var config = headerView.defaultContentConfiguration()

            // Must set header text here, otherwise defaultContentConfiguration overrides the current title
            config.text = "Start tracking your trips outside of Canada by clicking the ＋ button in the top-right."
            config.textProperties.alignment = .center

            headerView.contentConfiguration = config
        } else {
            print("A problem occurred casting view parameter to UITableHeaderFooterView.")
        }
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
    
    @objc func shareBarButtonPressed() {
        if !MFMailComposeViewController.canSendMail() {
            let ac = UIAlertController(title: "Can't Send Email", message: "Email services are not enabled on your device.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        let composeVC = MFMailComposeViewController()
        composeVC.mailComposeDelegate = self
         
        // Configure the fields of the interface.
        composeVC.setSubject("Travel Journal Spreadsheet")
        composeVC.setMessageBody("Attached is a CSV file containing all of my international trips.", isHTML: false)
        
        let csvString = createCSVContents(with: trips)
        let csvData = csvString.data(using: .utf8)
        
        composeVC.addAttachmentData(csvData!, mimeType: "text/csv", fileName: "travel-journal.csv")
         
        // Present the view controller modally.
        self.present(composeVC, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
    func createCSVContents(with trips: [Trip]) -> String {
        var contents = "Destination,Departure Date,Return Date,Days,Reason\n"
        
        for trip in trips {
            let departureDate = format(date: trip.departureDate)
            let returnDate = format(date: trip.returnDate)
            
            contents += "\"\(trip.destination)\",\"\(departureDate)\",\"\(returnDate)\",\"\(trip.days)\",\"\(trip.reason)\"\n"
        }
        
        return contents
    }
    
    func addTrip(_ trip: Trip) {
        trips.append(trip)
//        saveTrips()
        saveToiCloud()
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
    
    // MARK: CloudKit
    func getiCloudStatus() {
        CKContainer.default().accountStatus { [weak self] status, error in
            if let error {
                print(error)
                return
            }
            
            if status == .available {
                self?.userLoggedInToiCloud = true
                return
            }
            
            DispatchQueue.main.async {
                let ac = UIAlertController(title: "Not Logged In To iCloud", message: "Please log in to your iCloud account from your device's settings. Your trips will not be saved across devices.", preferredStyle: .alert)
                // TODO: Button action open the URL that openSettingsURLString constant provides
                ac.addAction(UIAlertAction(title: "I Understand", style: .default))
                self?.present(ac, animated: true)
            }
        }
    }
    
    func saveToiCloud()
    {
        let encoder = JSONEncoder()
        
        if let tripData = try? encoder.encode(trips) {
            let newTrips = CKRecord(recordType: "Trips")
            newTrips["travelJournalTrips"] = tripData
            
            CKContainer.default().privateCloudDatabase.save(newTrips) { returnedRecord, error in
                guard let returnedRecord else {
                    print("An error occurred: \(error!)")
                    return
                }
                
                print("Record saved!")
                print(returnedRecord)
            }
        }
    }
}

