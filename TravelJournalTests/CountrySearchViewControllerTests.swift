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
    
    override func setUp() {
        super.setUp()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        sut = storyboard.instantiateViewController(
            identifier: String(describing: CountrySearchViewController.self)
        )
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
}
