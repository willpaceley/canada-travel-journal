//
//  CountrySearchViewControllerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-04-22.
//

@testable import TravelJournal
import XCTest

final class CountrySearchViewControllerTests: XCTestCase {
    
    private var sut: CountrySearchViewController!
    private var delegateSpy: CountrySearchViewControllerDelegateSpy!
    
    override func setUp() {
        super.setUp()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        sut = storyboard.instantiateViewController(
            identifier: String(describing: CountrySearchViewController.self)
        )
        delegateSpy = CountrySearchViewControllerDelegateSpy()
        sut.delegate = delegateSpy
        sut.loadViewIfNeeded()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_tableViewDelegates_shouldBeSet() {
        XCTAssertNotNil(sut.tableView.delegate, "delegate")
        XCTAssertNotNil(sut.tableView.dataSource, "dataSource")
    }
    
    func test_searchBarDelegate_shouldBeSet() {
        XCTAssertNotNil(sut.navigationItem.searchController?.searchBar.delegate)
    }
    
    func test_countrySearchViewControllerDelegate_shouldBeSet() {
        XCTAssertNotNil(sut.delegate)
    }
}

class CountrySearchViewControllerDelegateSpy: CountrySearchViewControllerDelegate {
    var didPickCountryCalledCount = 0
    var didPickCountryArgs: [String] = []
    
    func countrySearchViewController(didPick country: String) {
        didPickCountryArgs.append(country)
        didPickCountryCalledCount += 1
    }
}
