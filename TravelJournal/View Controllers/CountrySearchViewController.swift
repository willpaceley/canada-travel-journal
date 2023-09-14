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
    
    let countries = Countries.all()
    var selectedCountry: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search for a country"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }
}

// MARK: UITableView Delegate
extension CountrySearchViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return countries.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: countryCell, for: indexPath)
        
        var contentConfiguration = cell.defaultContentConfiguration()
        contentConfiguration.text = countries[indexPath.row]
        cell.contentConfiguration = contentConfiguration
        
        return cell
    }
}

// MARK: UITableView Data Source
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
        print(text)
    }
}
