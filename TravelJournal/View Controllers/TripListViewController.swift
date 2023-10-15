//
//  TripListViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import UIKit
import CloudKit

class TripListViewController: UITableViewController {
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var shareButton: UIBarButtonItem!
    @IBOutlet var iCloudStatusButton: UIBarButtonItem!
    
    private let cloudKitManager = CloudKitManager()
    
    var dataModel: DataModel!
    var isLoading = false {
        didSet {
            isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataModel.delegate = self
        dataModel.cloudKitManager = cloudKitManager
        
        cloudKitManager.delegate = self
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.sizeToFit()
        title = "Canada Travel Journal"
        
        // Fetch most recent data when user pulls down on UITableView
        self.refreshControl?.addTarget(self, action: #selector(refreshTable), for: UIControl.Event.valueChanged)
    }
    
    // MARK: - @IBAction and @objc
    @IBAction func shareButtonPressed() {
        let csv = dataModel.createCSV()
        shareCSV(csv)
    }
    
    @objc func iCloudStatusButtonPressed() {
        guard let accountStatus = cloudKitManager.accountStatus else { return }
        
        var actions = [UIAlertAction]()
        if accountStatus != .available {
            let settingsAction = UIAlertAction(title: "Go to Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            actions.append(settingsAction)
        }
        let cancelAction = UIAlertAction(title: "OK", style: .default)
        actions.append(cancelAction)
        
        let (title, message) = getiCloudInstructions(for: accountStatus)
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        for action in actions {
            alertController.addAction(action)
        }
       
        present(alertController, animated: true)
    }
    
    @objc func refreshTable() {
        dataModel.loadTrips()
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! TripDetailViewController
        vc.delegate = self
        
        if segue.identifier == editTripSegueId {
            let tripToEdit = sender as? Trip
            vc.tripToEdit = tripToEdit
        }
    }
    
    // MARK: - UI Updates
    func reloadFooter() {
        tableView.beginUpdates()
        
        var contentConfig = tableView.footerView(forSection: 0)?.defaultContentConfiguration()
        contentConfig?.text = !dataModel.trips.isEmpty ? "Total days outside of Canada: \(dataModel.totalDays)" : nil
        tableView.footerView(forSection: 0)?.contentConfiguration = contentConfig
        
        tableView.endUpdates()
    }
    
    func createCKStatusButton(for accountStatus: CKAccountStatus) -> UIButton {
        let systemName = accountStatus == .available ? "checkmark.icloud" : "icloud.slash"
        let accentColor: UIColor = accountStatus == .available ? .systemGreen : .systemRed
        var symbolConfig = UIImage.SymbolConfiguration(paletteColors: [accentColor, .tertiaryLabel])
        symbolConfig = symbolConfig.applying(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 22)))
        
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.setPreferredSymbolConfiguration(symbolConfig, forImageIn: .normal)
        button.addTarget(self, action: #selector(iCloudStatusButtonPressed), for: .touchUpInside)
        
        return button
    }
    
    func shareCSV(_ csv: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = documentsDirectory.appendingPathComponent("TravelJournalTrips.csv")
        
        do {
            try csv.write(to: fileName, atomically: true, encoding: .utf8)
        } catch {
            print("An error occurred while creating the CSV file.")
            return
        }
        
        let vc = UIActivityViewController(activityItems: [fileName], applicationActivities: nil)
        vc.popoverPresentationController?.barButtonItem = shareButton
        present(vc, animated: true)
    }
    
    func getiCloudInstructions(for accountStatus: CKAccountStatus) -> (title: String, message: String) {
        var title: String
        var message = ""
        
        switch accountStatus {
        case .couldNotDetermine:
            title = "Could Not Determine iCloud Status"
        case .available:
            title = "Connected To iCloud"
        case .restricted:
            title = "iCloud Access Restricted"
        case .noAccount:
            title = "No iCloud Account"
            message += """
                        To fix this issue, ensure iCloud Drive is enabled in Settings. Please see instructions below.
                        
                        Step 1: Apple ID -> iCloud -> iCloud Drive -> Sync this iPhone (On)
                        
                        Step 2: Apple ID -> iCloud -> Show All Apps Using iCloud -> Travel Journal (On)
                        """
        case .temporarilyUnavailable:
            title = "iCloud Temporarily Unavailable"
            message += "Please ensure you are logged into iCloud in Settings."
        @unknown default:
            title = "Unknown iCloud Status"
        }
        
        if accountStatus != .available {
            message += "\n\nYour trips are being saved on your device. CAUTION: Deletion of this app will result in the permanent loss of your trip data."
        } else {
            message += "Your trip data is securely stored in a private iCloud database. You can access and update your trip data across all of your iOS devices."
        }
        
        return (title, message)
    }
    
    func displayAlert(title: String, message: String) {
        let ac = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension TripListViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataModel.trips.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Trip", for: indexPath) as! TripViewCell
        let trip = dataModel.trips[indexPath.row]
        
        cell.countryLabel.text = trip.destination
        cell.dateLabel.text = trip.departureDate.format()
        cell.daysLabel.text = "\(trip.days) \(trip.days > 1 ? "Days" : "Day")"
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension TripListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let trip = dataModel.trips[indexPath.row]
        performSegue(withIdentifier: editTripSegueId, sender: trip)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let ac = UIAlertController(title: "Delete Trip", message: "Are you sure you want to delete this trip?", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            ac.addAction(UIAlertAction(
                title: "Delete",
                style: .destructive,
                handler: { [weak self] _ in
                    self?.dataModel.delete(trip: (self?.dataModel.trips[indexPath.row])!)
                    self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self?.reloadFooter()
                }
            ))
            
            present(ac, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if !dataModel.trips.isEmpty {
            return "Total days outside of Canada: \(dataModel.totalDays)"
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataModel.trips.isEmpty ? "Click the ＋ button to add a new trip!" : nil
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50.0
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            var config = headerView.defaultContentConfiguration()

            // Must set header text here, otherwise defaultContentConfiguration overrides the current title
            config.text = "Start tracking your trips outside of Canada by clicking the ＋ button in the top-right."
            config.textProperties.alignment = .center
            config.textProperties.numberOfLines = 0

            headerView.contentConfiguration = config
        } else {
            print("A problem occurred casting header view parameter to UITableHeaderFooterView.")
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let footerView = view as? UITableViewHeaderFooterView {
            var config = footerView.defaultContentConfiguration()
            config.text = "Total days outside of Canada: \(dataModel.totalDays)"
            footerView.contentConfiguration = config
        } else {
            print("A problem occurred casting footer view parameter to UITableHeaderFooterView.")
        }
    }
}

// MARK: - DataModelDelegate
extension TripListViewController: DataModelDelegate {
    func dataModelDidSaveTrips() {
        shareButton.isEnabled = !dataModel.trips.isEmpty
        print("dataModelDidSaveTrips() was called.")
    }
    
    func dataModelDidLoadTrips() {
        isLoading = false
        refreshControl?.endRefreshing()
        shareButton.isEnabled = !dataModel.trips.isEmpty
        tableView.reloadData()
    }
    
    func dataModel(didHaveLoadError error: Error) {
        isLoading = false
        refreshControl?.endRefreshing()
        
        displayAlert(
            title: "Loading Error",
            message: error.localizedDescription
        )
    }
    
    func dataModel(didHaveSaveError error: Error) {
        var alert: (title: String, message: String)
        
        // TODO: Create a TJError type
        // TODO: Create an alert context to provides alerts for all errors in app
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable:
                alert = (
                    title: "Network Unavailable",
                    message: "The Internet connection appears to be offline."
                )
            case .notAuthenticated:
                alert = (
                    title: "iCloud Drive Not Enabled",
                    message: "Please turn on iCloud Drive in the Settings for your device. Your trips will not be saved."
                )
            default:
                alert = (
                    title: "iCloud Save Error",
                    message: "\(error.localizedDescription). CKError Code: \(ckError.code.rawValue)"
                )
            }
        } else {
            alert = (
                title: "Save Error",
                message: error.localizedDescription
            )
        }
        
        displayAlert(title: alert.title, message: alert.message)
    }
}

// MARK: - CloudKitManagerDelegate
extension TripListViewController: CloudKitManagerDelegate {
    func cloudKitManager(accountStatusChanged accountStatus: CKAccountStatus) {
        let button = createCKStatusButton(for: accountStatus)
        iCloudStatusButton.customView = button
        dataModel.loadTrips()
        refreshControl?.endRefreshing()
    }
    
    func cloudKitManager(didHaveError error: Error) {
        isLoading = false
        displayAlert(
            title: "iCloud Status Error",
            message: error.localizedDescription
        )
    }
}

// MARK: - TripDetailViewControllerDelegate
extension TripListViewController: TripDetailViewControllerDelegate {
    func tripDetailViewControllerDidAdd(_ trip: Trip) {
        dataModel.add(trip: trip)
        tableView.reloadData()
    }
    
    func tripDetailViewControllerDidUpdate(_ trip: Trip) {
        if let index = dataModel.trips.firstIndex(where: {$0.id == trip.id}) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
            reloadFooter()
        }
    }
    
    func tripDetailViewControllerDidDelete(_ trip: Trip) {
        if let index = dataModel.trips.firstIndex(where: {$0.id == trip.id}) {
            dataModel.delete(trip: trip)
            let indexPath = IndexPath(row: index, section: 0)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            reloadFooter()
        }
    }
}
