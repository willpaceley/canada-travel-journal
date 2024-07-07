//
//  TestHelpers.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-05-07.
//

import UIKit

// MARK: Global Methods
func executeRunLoop() {
    RunLoop.current.run(until: .now)
}

func putInWindow(_ vc: UIViewController) {
    let window = UIWindow()
    window.rootViewController = vc
    window.isHidden = false
}

