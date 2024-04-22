//
//  CountrySearchViewControllerTests.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-04-22.
//

@testable import TravelJournal
import XCTest

final class CountrySearchViewControllerTests: XCTestCase {

    func test_load() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let sut: CountrySearchViewController = sb.instantiateViewController(
            identifier: String(describing: CountrySearchViewController.self)
        )
        sut.loadViewIfNeeded()
        
        XCTAssertNotNil(sut.searchString)
    }

}
