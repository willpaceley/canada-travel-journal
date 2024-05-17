//
//  LocalStorage.swift
//  TravelJournal
//
//  Created by Will Paceley on 2024-05-17.
//

import Foundation

protocol LocalStorage {
    func object(forKey defaultName: String) -> Any?
    func setValue(_ value: Any?, forKey key: String)
}

extension UserDefaults: LocalStorage {}
