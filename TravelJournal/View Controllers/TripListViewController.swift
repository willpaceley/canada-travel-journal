//
//  TripListViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-06.
//

import UIKit
import CloudKit
import Network
import OSLog

fileprivate let logger = Logger(category: "TripListViewController")

class TripListViewController: UITableViewController {
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var persistenceStatusButton: UIBarButtonItem!
    @IBOutlet var addTripButton: UIBarButtonItem!
    @IBOutlet var shareButton: UIBarButtonItem!
    
    private var trips = [Trip]()
    
    private var isLoading = false {
        didSet {
            if isLoading {
                UIAccessibility.announce(message: "Loading")
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
                refreshControl?.endRefreshing()
            }
        }
    }
    private var totalDays: Int {
        trips.reduce(0) { $0 + $1.days }
    }
    
    let dataService = TripDataService(
        cloudKitManager: CloudKitManager(),
        connectivityManager: ConnectivityManager()
    )
    
    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataService.delegate = self
        dataService.connectivityManager.startMonitor()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "My Trips"
        
        // Fetch most recent data when user pulls down on UITableView
        self.refreshControl?.addTarget(self, action: #selector(refreshTable), for: UIControl.Event.valueChanged)
        
        setupAccessibility()
    }
    
    // MARK: - @IBAction and @objc
    @IBAction func shareButtonPressed() {
        let csvContent = CSVUtility.generateCSVContent(from: trips)
        
        do {
            try CSVUtility.writeCSVFile(csvContent: csvContent)
        } catch {
            logger.error("An error occurred writing the CSV file to the device.")
            return
        }
        
        let csvFile = CSVUtility.getCSVFilePath()
        let vc = UIActivityViewController(activityItems: [csvFile], applicationActivities: nil)
        vc.popoverPresentationController?.barButtonItem = shareButton
        present(vc, animated: true)
    }
    
    @objc func persistenceStatusButtonPressed() {
        var actions = [UIAlertAction]()
        // TODO: Add force crash button for unknown persistenceStatus
        if dataService.persistenceStatus != .iCloudAvailable {
            let settingsAction = UIAlertAction(title: "Go to Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            actions.append(settingsAction)
        }
        let cancelAction = UIAlertAction(title: "OK", style: .default)
        actions.append(cancelAction)
        
        let (title, message) = PersistenceAlertFactory.alert(for: dataService.persistenceStatus)
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        for action in actions {
            alertController.addAction(action)
        }
       
        present(alertController, animated: true)
    }
    
    @objc func refreshTable() {
        loadTrips()
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
    
    // MARK: - Accessibility
    func setupAccessibility() {
        shareButton.accessibilityLabel = "Share"
        shareButton.accessibilityHint = "Share a spreadsheet of your trips."
        
        persistenceStatusButton.accessibilityLabel = "App Status"
        persistenceStatusButton.accessibilityHint = "View the current status of the application."
        
        addTripButton.accessibilityHint = "Add a new trip."
    }
    
    // MARK: - UI Updates
    func reloadFooter() {
        tableView.beginUpdates()
        
        var contentConfig = tableView.footerView(forSection: 0)?.defaultContentConfiguration()
        contentConfig?.text = !trips.isEmpty ? "Total days outside of Canada: \(totalDays)" : nil
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
        symbolConfig = symbolConfig.applying(
            UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .title2))
        )
        
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemIcon), for: .normal)
        button.setPreferredSymbolConfiguration(symbolConfig, forImageIn: .normal)
        button.addTarget(self, action: #selector(persistenceStatusButtonPressed), for: .touchUpInside)
        
        return button
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
    
    // MARK: - Helper Methods
    private func sortByReverseChronological() {
        trips.sort { $0.departureDate > $1.departureDate }
    }
    
    private func loadTrips() {
        logger.log("Loading trips.")
        dataService.loadTrips { [weak self] result in
            switch result {
            case .success(let trips):
                if let trips {
                    self?.trips = trips
                    self?.iCloudDataUpdate()
                    UIAccessibility.announce(message: "Loaded trips.")
                    DispatchQueue.main.async {
                        self?.shareButton.isEnabled = !trips.isEmpty
                        self?.tableView.reloadData()
                    }
                }
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            case .failure(let error):
                if error != .unknownPersistenceStatus {
                    let (title, message) = ErrorAlertFactory.loadErrorAlert(for: error)
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.displayAlert(title: title, message: message)
                    }
                }
            }
        }
    }
    
    private func deleteTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips.remove(at: index)
            dataService.save(trips)
            let indexPath = IndexPath(row: index, section: 0)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            shareButton.isEnabled = !trips.isEmpty
            reloadFooter()
        } else {
            logger.error("There was a problem finding the index of the trip to delete")
        }
    }
    
    private func iCloudDataUpdate() {
        // Save the trip data if iCloud is not updated with latest data
        logger.debug("Checking if we should save on-device trips to iCloud.")
        let onDeviceTripDataLastModified = UserDefaults.standard.object(
            forKey: onDeviceDataLastModifiedKey
        ) as? Date ?? Date.distantPast
        if let cloudKitTripDataLastModified = dataService.cloudKitManager.cloudKitTripDataLastModified {
            let onDeviceDataIsMoreRecent = onDeviceTripDataLastModified > cloudKitTripDataLastModified
            if onDeviceDataIsMoreRecent && dataService.persistenceStatus == .iCloudAvailable {
                logger.log("Saving more recent trip data from device to iCloud.")
                dataService.save(trips)
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension TripListViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trips.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Trip", for: indexPath) as! TripViewCell
        let trip = trips[indexPath.row]
        
        cell.countryLabel.text = trip.destination
        cell.dateLabel.text = trip.departureDate.format()
        cell.daysLabel.text = "\(trip.days) \(trip.days > 1 ? "Days" : "Day")"
        cell.accessibilityHint = "Edit the details of this trip."
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension TripListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let trip = trips[indexPath.row]
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
                    let trip = self?.trips[indexPath.row]
                    self?.deleteTrip(trip!)
                }
            ))
            
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
        // willDisplayHeaderView(_:view:section:) provides content for the header
        return trips.isEmpty ? " " : nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            var config = headerView.defaultContentConfiguration()

            // Must set header text here, otherwise defaultContentConfiguration overrides the current title
            config.text = "Add your first trip by clicking the ＋ button in the top-right corner."
            config.textProperties.font = .preferredFont(forTextStyle: .headline)
            config.textProperties.lineBreakMode = .byWordWrapping
            config.textProperties.numberOfLines = 0

            headerView.contentConfiguration = config
        } else {
            logger.error("A problem occurred casting header view parameter to UITableHeaderFooterView.")
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let footerView = view as? UITableViewHeaderFooterView {
            var config = footerView.defaultContentConfiguration()
            config.text = "Total days outside of Canada: \(totalDays)"
            footerView.contentConfiguration = config
        } else {
            logger.error("A problem occurred casting footer view parameter to UITableHeaderFooterView.")
        }
    }
}

// MARK: - TripDetailViewControllerDelegate
extension TripListViewController: TripDetailViewControllerDelegate {
    func tripDetailViewControllerDidAdd(_ trip: Trip) {
        trips.append(trip)
        sortByReverseChronological()
        dataService.save(trips)
        
        shareButton.isEnabled = !trips.isEmpty
        tableView.reloadData()
    }
    
    func tripDetailViewControllerDidUpdate(_ trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            dataService.save(trips)
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
            reloadFooter()
        } else {
            logger.error("There was a problem finding the index of the trip to update.")
        }
    }
    
    func tripDetailViewControllerDidDelete(_ trip: Trip) {
        if let index = trips.firstIndex(where: {$0.id == trip.id}) {
            trips.remove(at: index)
            dataService.save(trips)
            let indexPath = IndexPath(row: index, section: 0)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            shareButton.isEnabled = !trips.isEmpty
            reloadFooter()
        } else {
            logger.error("There was a problem finding the index of the trip to delete.")
        }
    }
}

// MARK: - TripsDataServiceDelegate
extension TripListViewController: TripDataServiceDelegate {
    func dataServicePersistenceStatusChanged(from oldStatus: PersistenceStatus, to status: PersistenceStatus) {
        logger.log("Data service persistence status changed to: \(status, privacy: .public)")
        
        let button = createPersistenceStatusButton(for: status)
        persistenceStatusButton.customView = button
        
        // Unknown status occurs when NWPathMonitor status changes to .connected
        if status == .unknown {
            isLoading = true
            dataService.cloudKitManager.requestAccountStatus()
            return
        }
        
        // Attempt to load trips if there are none
        if trips.isEmpty {
            isLoading = true
            loadTrips()
            return
        }
        
        // Save the data if the status was offline then turned to iCloud available
        if oldStatus == .networkUnavailable || oldStatus == .iCloudUnavailable {
            logger.log("CloudKit has become available, checking if offline changes should be saved.")
            iCloudDataUpdate()
        }
        
        isLoading = false
    }
    
    func dataService(didHaveSaveError error: TravelJournalError) {
        isLoading = false
        let (title, message) = ErrorAlertFactory.saveErrorAlert(for: error)
        displayAlert(title: title, message: message)
    }
    
    func dataService(didHaveCloudKitError error: CKError) {
        isLoading = false
        let (title, message) = ErrorAlertFactory.cloudKitErrorAlert(for: error)
        displayAlert(title: title, message: message)
    }
}
