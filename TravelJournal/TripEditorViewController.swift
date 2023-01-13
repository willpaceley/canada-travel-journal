//
//  TripEditorViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-01-07.
//

import UIKit

class TripEditorViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
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
        // Populate countries array
        for code in NSLocale.isoCountryCodes  {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            let name = NSLocale(localeIdentifier: "en_CA").displayName(forKey: NSLocale.Key.identifier, value: id) ?? "Country not found for code: \(code)"
            countries.append(name)
        }
        
        // Sort the countries alphabetically
        countries.sort()
    }
    
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
        let selectedCountry = countries[row]
        if selectedCountry != tripToEdit?.destination {
            doneButton?.isEnabled = true
        } else {
            doneButton?.isEnabled = false
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        reasonField.resignFirstResponder()
        return true
    }
    
    @objc func trashButtonPressed() {
        let ac = UIAlertController(title: "Delete Trip", message: "Are you sure you want to delete this trip?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            let trip = self?.tripToEdit
            self?.delegate.deleteTrip(trip!)
            self?.navigationController?.popViewController(animated: true)
        }))
        
        present(ac, animated: true)
    }
    
    @objc func doneButtonPressed() {
        
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
    
    func presentAlert(title: String?, message: String?) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
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
        if sender.date != tripToEdit?.departureDate {
            doneButton?.isEnabled = true
        } else {
            doneButton?.isEnabled = false
        }
    }
    
    @IBAction func returnPickerValueChanged(_ sender: UIDatePicker) {
        if sender.date != tripToEdit?.returnDate {
            doneButton?.isEnabled = true
        } else {
            doneButton?.isEnabled = false
        }
    }
    
    @IBAction func reasonPickerValueChanged(_ sender: UITextField) {
        if let text = sender.text {
            if text != tripToEdit?.reason {
                doneButton?.isEnabled = true
            } else {
                doneButton?.isEnabled = false
            }
        }
    }
}
