//
//  TestHelpers.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-05-07.
//

import UIKit

extension UIButton {
    func tap() {
        self.sendActions(for: .touchUpInside)
    }
}

extension UIBarButtonItem {
    func tap() {
        _ = self.target?.perform(self.action, with: nil)
    }
}
