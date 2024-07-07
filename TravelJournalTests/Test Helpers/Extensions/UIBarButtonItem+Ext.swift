//
//  UIBarButtonItem+Ext.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-07-07.
//

import UIKit

extension UIBarButtonItem {
    /// Taps on a bar button item
    func tap() {
        _ = self.target?.perform(self.action, with: nil)
    }
}
