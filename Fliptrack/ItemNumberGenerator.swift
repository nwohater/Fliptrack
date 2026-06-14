//
//  ItemNumberGenerator.swift
//  Fliptrack
//
//  Created by Codex on 6/12/26.
//

import Foundation

enum ItemNumberGenerator {
    private static let counterKey = "fliptrack.itemNumberCounter"

    static func previewNextItemNumber(defaults: UserDefaults = .standard) -> String {
        makeItemNumber(counter: defaults.integer(forKey: counterKey) + 1)
    }

    static func nextItemNumber(defaults: UserDefaults = .standard) -> String {
        let nextCounter = defaults.integer(forKey: counterKey) + 1
        defaults.set(nextCounter, forKey: counterKey)
        return makeItemNumber(counter: nextCounter)
    }

    private static func makeItemNumber(counter: Int) -> String {
        String(format: "%04d", counter)
    }
}
