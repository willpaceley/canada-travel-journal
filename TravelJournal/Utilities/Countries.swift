//
//  Countries.swift
//  TravelJournal
//
//  Created by Will Paceley on 2023-09-14.
//

import Foundation

struct Countries {
    // Method to populate country array using NSLocale.isoCountryCodes by Amir Sk on Stack Overflow
    // Link: https://stackoverflow.com/questions/27875463/how-do-i-get-a-list-of-countries-in-swift-ios
    static func all() -> [String] {
        var countries = [String]()
        let userLocaleId = Locale.current.identifier
        
        for code in NSLocale.isoCountryCodes  {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            if let name = NSLocale(localeIdentifier: userLocaleId).displayName(forKey: NSLocale.Key.identifier, value: id) {
                countries.append(name)
            }
        }
        
        // Sort the countries alphabetically, accounting for diacritics in our locale
        countries.sort { $0.compare($1, locale: NSLocale.current) == .orderedAscending }
        
        return countries
    }
}
