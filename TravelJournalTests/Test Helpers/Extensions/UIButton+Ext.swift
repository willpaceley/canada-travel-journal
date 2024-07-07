//
//  UIButton+Ext.swift
//  TravelJournalTests
//
//  Created by Will Paceley on 2024-07-07.
//

import UIKit

extension UIButton {
    /// Taps on a button with the `.touchUpInside` action
    func tap() {
        self.sendActions(for: .touchUpInside)
    }
}
