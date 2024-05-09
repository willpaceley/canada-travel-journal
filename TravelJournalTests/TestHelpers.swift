//
//  TestHelpers.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-05-07.
//

import UIKit

extension UIButton {
    /// Taps on a button with the `.touchUpInside` action
    func tap() {
        self.sendActions(for: .touchUpInside)
    }
}

extension UIBarButtonItem {
    /// Taps on a bar button item
    func tap() {
        _ = self.target?.perform(self.action, with: nil)
    }
}
