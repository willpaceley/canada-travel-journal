//
//  TripDetailViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-07.
//

import UIKit

protocol TripDetailViewControllerDelegate: AnyObject {
    func tripDetailViewControllerDidAdd(_ trip: Trip)
    func tripDetailViewControllerDidUpdate(_ trip: Trip)
    func tripDetailViewControllerDidDelete(_ trip: Trip)
}

class TripDetailViewController: UITableViewController {
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var countryLabel: UILabel!
    @IBOutlet var reasonField: UITextField!
    @IBOutlet var returnPicker: UIDatePicker!
    @IBOutlet var departurePicker: UIDatePicker!
    var doneButton: UIBarButtonItem?
    
    weak var delegate: TripDetailViewControllerDelegate!
    
    var tripToEdit: Trip?
    var selectedCountry: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.largeTitleDisplayMode = .never
        
        // Set the view controller delegates
        reasonField.delegate = self
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(adjustForKeyboard),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(adjustForKeyboard),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        
        if let trip = tripToEdit {
            title = "Edit Trip"
            saveButton.isHidden = true
            
            departurePicker.date = trip.departureDate
            returnPicker.date = trip.returnDate
            reasonField.text = trip.reason
            countryLabel.text = trip.destination
            selectedCountry = trip.destination
            
            // Add navigation bar buttons for update and delete operations
            doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
            doneButton?.isEnabled = false
            let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashButtonPressed))
            navigationItem.rightBarButtonItems = [doneButton!, deleteButton]
        } else {
            title = "Add New Trip"
        }
    }
    
    @objc func trashButtonPressed() {
        let ac = UIAlertController(title: "Delete Trip", message: "Are you sure you want to delete this trip?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            let trip = self.tripToEdit
            self.delegate.tripDetailViewControllerDidDelete(trip!)
            
            self.navigationController?.popViewController(animated: true)
        }))
        
        present(ac, animated: true)
    }
    
    @objc func doneButtonPressed() {
        tripToEdit?.departureDate = departurePicker.date
        tripToEdit?.returnDate = returnPicker.date
        tripToEdit?.reason = reasonField.text!
        tripToEdit?.destination = countryLabel.text!
        
        delegate.tripDetailViewControllerDidUpdate(tripToEdit!)
        navigationController?.popViewController(animated: true)
    }
    
    // adjustForKeyboard(notification:) code authored by Paul Hudson
    // https://www.hackingwithswift.com/example-code/uikit/how-to-adjust-a-uiscrollview-to-fit-the-keyboard
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

        if notification.name == UIResponder.keyboardWillHideNotification {
            tableView.contentInset = .zero
        } else {
            tableView.contentInset = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom,
                right: 0
            )
        }

        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    func tripIsValid() -> Bool {
        let departureDate = departurePicker.date
        let returnDate = returnPicker.date
        
        if returnDate < departureDate {
            presentAlert(title: "Invalid Trip Dates", message: "Your departure date must be on the same day or before your return date.")
            return false
        }
        
        if reasonField.text == nil || reasonField.text! == "" {
            presentAlert(title: "No Reason Entered", message: "Please enter a reason for your travel outside of the country.")
            return false
        }
        
        return true
    }
    
    func dataChanged(for trip: Trip) -> Bool {
        let departureChanged = departurePicker.date != trip.departureDate
        let returnChanged = returnPicker.date != trip.returnDate
        let reasonChanged = reasonField.text! != trip.reason
        let destinationChanged = countryLabel.text! != trip.destination
        
        return departureChanged || returnChanged || reasonChanged || destinationChanged
    }
    
    func presentAlert(title: String?, message: String?) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    // MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == pickCountrySegueId {
            let vc = segue.destination as! CountrySearchViewController
            vc.delegate = self
            
            if let selectedCountry {
                vc.selectedCountry = selectedCountry
            }
        }
    }
    
    // MARK: IBActions
    @IBAction func addTripButtonPressed(_ sender: Any) {
        if tripIsValid() {
            let id = UUID().uuidString
            // TODO: Improve type safety
            let country = countryLabel.text ?? "Unknown country"
            let reason = reasonField.text ?? "Unknown reason"
            
            let newTrip = Trip(id: id, departureDate: departurePicker.date, returnDate: returnPicker.date, destination: country, reason: reason)
            delegate.tripDetailViewControllerDidAdd(newTrip)
            
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func departurePickerValueChanged(_ sender: UIDatePicker) {
        if departurePicker.date > returnPicker.date {
            returnPicker.setDate(departurePicker.date, animated: true)
        }
        
        doneButton?.isEnabled = dataChanged(for: tripToEdit!)
    }
    
    @IBAction func returnPickerValueChanged(_ sender: UIDatePicker) {
        if returnPicker.date < departurePicker.date {
            departurePicker.setDate(returnPicker.date, animated: true)
        }
        
        doneButton?.isEnabled = dataChanged(for: tripToEdit!)
    }
    
    @IBAction func reasonPickerValueChanged(_ sender: UITextField) {
        doneButton?.isEnabled = dataChanged(for: tripToEdit!)
    }
}

// MARK: - UITableViewDelegate
extension TripDetailViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        // Only allow country row to be selected
        if indexPath.section == 1 {
            return indexPath
        }
        return nil
    }
}

// MARK: - UITextFieldDelegate
extension TripDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - CountrySearchViewControllerDelegate
extension TripDetailViewController: CountrySearchViewControllerDelegate {
    func countrySearchViewController(didPick country: String) {
        countryLabel.text = country
        selectedCountry = country
        doneButton?.isEnabled = dataChanged(for: tripToEdit!)
        navigationController?.popViewController(animated: true)
    }
}
