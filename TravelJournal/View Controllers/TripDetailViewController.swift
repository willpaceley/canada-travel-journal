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
    @IBOutlet var addTripButton: UIButton!
    @IBOutlet var countryLabel: UILabel!
    @IBOutlet var reasonField: UITextField!
    @IBOutlet var returnPicker: UIDatePicker!
    @IBOutlet var departurePicker: UIDatePicker!
    @IBOutlet var doneButton: UIBarButtonItem!
    
    weak var delegate: TripDetailViewControllerDelegate!
    
    var tripToEdit: Trip?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reasonField.delegate = self
        
        navigationItem.largeTitleDisplayMode = .never
        setupKeyboardNotifications()
        
        if let trip = tripToEdit {
            title = "Edit Trip"
            addTripButton.isHidden = true
            doneButton.accessibilityHint = "Trip data has not changed."
            
            departurePicker.date = trip.departureDate
            returnPicker.date = trip.returnDate
            reasonField.text = trip.reason
            countryLabel.text = trip.destination
        } else {
            title = "Add New Trip"
            navigationItem.rightBarButtonItems = nil
            addTripButton.accessibilityHint = "All fields are required."
        }
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == pickCountrySegueId {
            let vc = segue.destination as! CountrySearchViewController
            vc.delegate = self
            
            if let country = countryLabel.text, !country.isEmpty {
                vc.selectedCountry = country
            }
        }
    }
    
    // MARK: - @IBActions
    @IBAction func addTripButtonPressed(_ sender: UIButton) {
        guard let country = countryLabel.text else { return }
        guard let reason = reasonField.text else { return }
        
        if tripIsValid() {
            let newTrip = Trip(
                departureDate: departurePicker.date,
                returnDate: returnPicker.date,
                destination: country,
                reason: reason
            )
            
            delegate.tripDetailViewControllerDidAdd(newTrip)
            navigationController?.popViewController(animated: true)
        }
        
        // TODO: Provide VoiceOver feedback if trip is invalid
    }
    
    @IBAction func doneButtonPressed() {
        guard tripToEdit != nil else { return }
        
        tripToEdit!.departureDate = departurePicker.date
        tripToEdit!.returnDate = returnPicker.date
        tripToEdit!.reason = reasonField.text!
        tripToEdit!.destination = countryLabel.text!
        
        delegate.tripDetailViewControllerDidUpdate(tripToEdit!)
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func trashButtonPressed() {
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
    
    @IBAction func inputValueChanged(_ sender: Any) {
        if let tripToEdit {
            let tripDataChanged = dataChanged(for: tripToEdit)
            doneButton.isEnabled = tripDataChanged
            doneButton.accessibilityHint = !tripDataChanged ? "Trip data has not changed." : nil
        } else {
            let tripIsValid = tripIsValid()
            addTripButton.isEnabled = tripIsValid
            addTripButton.accessibilityHint = !tripIsValid ? "All fields are required." : nil
        }
    }
    
    @IBAction func datePickerValueChanged(_ sender: UIDatePicker) {
        let departureDate = departurePicker.date
        let returnDate = returnPicker.date
        
        // Prevent user from selecting an invalid departure date
        if sender.tag == departurePickerTag {
            if departureDate.occursAfter(returnDate) {
                returnPicker.setDate(departureDate, animated: true)
            }
        }
        
        // Prevent user from selecting an invalid return date
        if sender.tag == returnPickerTag {
            if !returnDate.occursAfter(departureDate) {
                departurePicker.setDate(returnDate, animated: true)
            }
        }
        
        inputValueChanged(sender)
    }
    
    // MARK: - Validation
    func tripIsValid() -> Bool {
        let departureDate = departurePicker.date
        let returnDate = returnPicker.date
        
        guard returnDate.occursOnOrAfter(departureDate) else {
            return false
        }
        
        guard let reason = reasonField.text, !reason.isEmpty else {
            return false
        }
        
        guard let country = countryLabel.text, country != "Choose A Country" else {
            return false
        }
        
        return true
    }
    
    func dataChanged(for trip: Trip) -> Bool {
        let departureChanged = !trip.departureDate.isTheSameDate(as: departurePicker.date)
        let returnChanged = !trip.returnDate.isTheSameDate(as: returnPicker.date)
        let destinationChanged = trip.destination != countryLabel.text!
        let reasonChanged =  trip.reason != reasonField.text!
        
        return departureChanged || returnChanged || destinationChanged || reasonChanged
    }
    
    // MARK: - Keyboard Layout
    func setupKeyboardNotifications() {
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
        inputValueChanged(country)
        navigationController?.popViewController(animated: true)
        UIAccessibility.setVoiceOverFocus(to: countryLabel)
    }
}
