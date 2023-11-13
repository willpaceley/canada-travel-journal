//
//  TripListViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import UIKit
import CloudKit
import Network

class TripListViewController: UITableViewController {
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var persistenceStatusButton: UIBarButtonItem!
    @IBOutlet var shareButton: UIBarButtonItem!
    
    private var isLoading = false {
        didSet {
            if isLoading {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
                refreshControl?.endRefreshing()
            }
        }
    }
    
    var dataModel: DataModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataModel.delegate = self
        dataModel.connectivityManager.startMonitor()
        
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
    
    @objc func persistenceStatusButtonPressed() {
        var actions = [UIAlertAction]()
        if dataModel.persistenceStatus != .iCloudAvailable {
            let settingsAction = UIAlertAction(title: "Go to Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            actions.append(settingsAction)
        }
        let cancelAction = UIAlertAction(title: "OK", style: .default)
        actions.append(cancelAction)
        
        let (title, message) = PersistenceAlertFactory.alert(for: dataModel.persistenceStatus)
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
    
    func createPersistenceStatusButton(for persistenceStatus: PersistenceStatus) -> UIButton {
        let systemIcon: String
        let accentColor: UIColor
        
        switch persistenceStatus {
        case .iCloudAvailable:
            systemIcon = "checkmark.icloud"
        case .iCloudUnavailable:
            systemIcon = "xmark.icloud"
        case .networkUnavailable:
            systemIcon = "icloud.slash"
        case .unknown:
            systemIcon = "externaldrive.badge.questionmark"
        }
        
        accentColor = persistenceStatus == .iCloudAvailable ? .systemGreen : .systemRed
        var symbolConfig = UIImage.SymbolConfiguration(paletteColors: [accentColor, .tertiaryLabel])
        symbolConfig = symbolConfig.applying(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 22)))
        
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemIcon), for: .normal)
        button.setPreferredSymbolConfiguration(symbolConfig, forImageIn: .normal)
        button.addTarget(self, action: #selector(persistenceStatusButtonPressed), for: .touchUpInside)
        
        return button
    }
    
    func shareCSV(_ csv: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = documentsDirectory.appendingPathComponent("TravelJournalTrips.csv")
        
        do {
            try csv.write(to: fileName, atomically: true, encoding: .utf8)
        } catch {
            print("An error occurred while writing the CSV file to disc.")
            return
        }
        
        let vc = UIActivityViewController(activityItems: [fileName], applicationActivities: nil)
        vc.popoverPresentationController?.barButtonItem = shareButton
        present(vc, animated: true)
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
    func dataModelPersistenceStatus(changedTo status: PersistenceStatus) {
        print("Data model persistence status changed to: \(status)")
        // Unknown status occurs when device status changes to connected
        if status == .unknown {
            isLoading = true
            dataModel.cloudKitManager.requestAccountStatus()
            return
        }

        if dataModel.trips.isEmpty {
            isLoading = true
            dataModel.loadTrips()
        }
        
        isLoading = false
        let button = createPersistenceStatusButton(for: status)
        persistenceStatusButton.customView = button
    }
    
    func dataModelDidChange() {
        isLoading = false
        shareButton.isEnabled = !dataModel.trips.isEmpty
    }
    
    func dataModelDidLoadTrips() {
        isLoading = false
        shareButton.isEnabled = !dataModel.trips.isEmpty
        tableView.reloadData()
    }
    
    func dataModel(didHaveLoadError error: TravelJournalError) {
        isLoading = false
        
        if error != .unsavedChanges || error != .unknownPersistenceStatus {
            let (title, message) = ErrorAlertFactory.loadErrorAlert(for: error)
            displayAlert(title: title, message: message)
        }
    }
    
    func dataModel(didHaveSaveError error: TravelJournalError) {
        isLoading = false
        let (title, message) = ErrorAlertFactory.saveErrorAlert(for: error)
        displayAlert(title: title, message: message)
    }
    
    func dataModel(didHaveCloudKitError error: CKError) {
        isLoading = false
        let (title, message) = ErrorAlertFactory.cloudKitErrorAlert(for: error)
        displayAlert(title: title, message: message)
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
            dataModel.updatedTrip()
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
