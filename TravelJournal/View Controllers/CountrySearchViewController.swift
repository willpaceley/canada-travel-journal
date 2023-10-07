//
//  CountrySearchViewController.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-14.
//

import UIKit

protocol CountrySearchViewControllerDelegate: AnyObject {
    func countrySearchViewController(didPick country: String)
}

class CountrySearchViewController: UITableViewController {
    weak var delegate: CountrySearchViewControllerDelegate!
    
    var countries = Countries.all(excluding: ["CA"])
    var selectedCountry: String?
    var searchString = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search for a country"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // If a country is selected, automatically scroll to that row on load
        if let selectedCountry, let index = countries.firstIndex(of: selectedCountry) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
}

// MARK: UITableView Data Source
extension CountrySearchViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return countries.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: countryCell, for: indexPath)
        
        var contentConfiguration = cell.defaultContentConfiguration()
        let country = countries[indexPath.row]
        let attributedCountry = country.boldFirstNCharacters(n: searchString.count)
        contentConfiguration.attributedText = attributedCountry
        cell.contentConfiguration = contentConfiguration
        cell.accessibilityLabel = country
        cell.accessoryType = selectedCountry == country ? .checkmark : .none
        
        return cell
    }
}

// MARK: UITableViewDelegate
extension CountrySearchViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let country = countries[indexPath.row]
        delegate.countrySearchViewController(didPick: country)
    }
}

// MARK: UISearchResultsUpdating
extension CountrySearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        searchString = text
        
        let allCountries = Countries.all(excluding: ["CA"])
        if !text.isEmpty {
            let matchedCountries = allCountries.filter {
                $0.localizedLowercase.starts(with: text.localizedLowercase)
            }
            countries = matchedCountries
        } else {
            countries = allCountries
        }
        
        tableView.reloadData()
    }
}
