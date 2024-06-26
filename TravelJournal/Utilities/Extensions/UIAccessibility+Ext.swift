//
//  UIAccessibility+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-12-04.
//

import UIKit
import OSLog

fileprivate let logger = Logger(category: "UIAccessibility")

extension UIAccessibility {
    /// Changes VoiceOver's focus to the specified `view` parameter.
    ///
    /// > Note: This method only executes if VoiceOver is enabled on a physical device.
    static func setVoiceOverFocus(to view: UIView?) {
        guard UIAccessibility.isVoiceOverRunning else {
            return
        }
        
        guard view != nil else {
            logger.warning("UIView parameter was nil. Did not change VoiceOver focus.")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .layoutChanged, argument: view)
        }
    }
    
    /// Instruct VoiceOver to announce the `message` parameter to the user.
    ///
    /// > Note: This method only executes if VoiceOver is enabled on a physical device.
    static func announce(message: String) {
        guard UIAccessibility.isVoiceOverRunning else {
            return
        }
        
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
