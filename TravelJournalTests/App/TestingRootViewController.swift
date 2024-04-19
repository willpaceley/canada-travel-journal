//
//  TestingRootViewController.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-04-19.
//

import UIKit

class TestingRootViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func loadView() {
        let label = UILabel()
        label.text = "Running Unit Tests..."
        label.textAlignment = .center
        label.textColor = .white
        
        view = label
    }
}
