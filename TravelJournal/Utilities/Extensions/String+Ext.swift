//
//  String+Ext.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-15.
//

import UIKit

extension String {
    func boldFirstNCharacters(n numberOfCharacters: Int) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self)
        let range = NSRange(location: 0, length: numberOfCharacters)
        attributedString.addAttribute(
            .font,
            value: UIFont.preferredFont(forTextStyle: .headline),
            range: range
        )
        return attributedString
    }
}
