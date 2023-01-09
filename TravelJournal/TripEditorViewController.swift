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

    @IBOutlet var saveButton: UIButton!
    @IBOutlet var countryPicker: UIPickerView!
    @IBOutlet var reasonField: UITextField!
    @IBOutlet var returnPicker: UIDatePicker!
    @IBOutlet var departurePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = tripToEdit != nil ? "Edit Trip" : "Add New Trip"
        navigationItem.largeTitleDisplayMode = .never
        
        populateCountries()
        
        // Set the view controller delegates
        countryPicker.delegate = self
        countryPicker.dataSource = self
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        reasonField.resignFirstResponder()
        return true
    }
    
    @IBAction func addTripButtonPressed(_ sender: Any) {
        if tripIsValid() {
            let countryIndex = countryPicker.selectedRow(inComponent: 0)
            let country = countries[countryIndex]
            let reason = reasonField.text ?? "Unknown reason"
            
            let newTrip = Trip(departureDate: departurePicker.date, returnDate: returnPicker.date, destination: country, reason: reason)
            delegate.addTrip(newTrip)
            
            navigationController?.popViewController(animated: true)
        }
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
}
