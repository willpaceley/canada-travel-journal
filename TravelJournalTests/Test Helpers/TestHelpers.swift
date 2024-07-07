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

// MARK: UIButton
extension UIButton {
    /// Taps on a button with the `.touchUpInside` action
    func tap() {
        self.sendActions(for: .touchUpInside)
    }
}

// MARK: UIBarButtonItem
extension UIBarButtonItem {
    /// Taps on a bar button item
    func tap() {
        _ = self.target?.perform(self.action, with: nil)
    }
}
