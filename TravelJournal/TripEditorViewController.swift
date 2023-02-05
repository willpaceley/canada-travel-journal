//
//  TripEditorViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-07.
//

import UIKit

class TripEditorViewController: UIViewController {
    var tripToEdit: Trip?
    var countries = [String]()
    
    weak var delegate: ViewController!
    
    var doneButton: UIBarButtonItem?
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var countryPicker: UIPickerView!
    @IBOutlet var reasonField: UITextField!
    @IBOutlet var returnPicker: UIDatePicker!
    @IBOutlet var departurePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.largeTitleDisplayMode = .never
        
        populateCountries()
        
        // Set the view controller delegates
        countryPicker.delegate = self
        countryPicker.dataSource = self
        reasonField.delegate = self
        
        if let trip = tripToEdit {
            title = "Edit Trip"
            saveButton.isHidden = true
            
            departurePicker.date = trip.departureDate
            returnPicker.date = trip.returnDate
            reasonField.text = trip.reason
            
            if let countryIndex = countries.firstIndex(of: trip.destination) {
                countryPicker.selectRow(countryIndex, inComponent: 0, animated: true)
            } else {
                print("Could not find specified country from tripToEdit in countries array.")
            }
            
            // Add navigation bar buttons for update and delete operations
            doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
            doneButton?.isEnabled = false
            let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashButtonPressed))
            navigationItem.rightBarButtonItems = [doneButton!, deleteButton]
        } else {
            title = "Add New Trip"
        }
    }
    
    func populateCountries() {
        // Method to populate country array using NSLocale.isoCountryCodes by Amir Sk on Stack Overflow
        // Link: https://stackoverflow.com/questions/27875463/how-do-i-get-a-list-of-countries-in-swift-ios
        
        for code in NSLocale.isoCountryCodes  {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            let name = NSLocale(localeIdentifier: "en_CA").displayName(forKey: NSLocale.Key.identifier, value: id) ?? "Country not found for code: \(code)"
            countries.append(name)
        }
        
        // Sort the countries alphabetically
        countries.sort()
    }
    
    @objc func trashButtonPressed() {
        let ac = UIAlertController(title: "Delete Trip", message: "Are you sure you want to delete this trip?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        
            let trip = self?.tripToEdit
            self?.delegate.deleteTrip(trip!)
        }))
        
        present(ac, animated: true)
    }
    
    @objc func doneButtonPressed() {
        tripToEdit?.departureDate = departurePicker.date
        tripToEdit?.returnDate = returnPicker.date
        tripToEdit?.reason = reasonField.text!
        tripToEdit?.destination = countries[countryPicker.selectedRow(inComponent: 0)]
        
        delegate.updateTrip(tripToEdit!)
        navigationController?.popViewController(animated: true)
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
        let destinationChanged = countries[countryPicker.selectedRow(inComponent: 0)] != trip.destination
        
        return departureChanged || returnChanged || reasonChanged || destinationChanged
    }
    
    func presentAlert(title: String?, message: String?) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    // MARK: IBActions
    @IBAction func addTripButtonPressed(_ sender: Any) {
        if tripIsValid() {
            let id = UUID().uuidString
            let countryIndex = countryPicker.selectedRow(inComponent: 0)
            let country = countries[countryIndex]
            let reason = reasonField.text ?? "Unknown reason"
            
            let newTrip = Trip(id: id, departureDate: departurePicker.date, returnDate: returnPicker.date, destination: country, reason: reason)
            delegate.addTrip(newTrip)
            
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

// MARK: Extensions
extension TripEditorViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return countries.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return countries[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        doneButton?.isEnabled = dataChanged(for: tripToEdit!)
    }
}

extension TripEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        reasonField.resignFirstResponder()
        return true
    }
}
