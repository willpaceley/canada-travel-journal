//
//  UIAccessibility+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-12-04.
//

import UIKit

extension UIAccessibility {
    /// Changes VoiceOver's focus to the specified `view` parameter.
    ///
    /// > Note: This method only executes if VoiceOver is enabled on a physical device.
    static func setVoiceOverFocus(to view: UIView) {
        guard UIAccessibility.isVoiceOverRunning else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .layoutChanged, argument: view)
        }
    }
}
