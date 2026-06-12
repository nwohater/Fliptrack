//
//  ItemNumberGenerator.swift
//  Fliptrack
//
//  Created by Codex on 6/12/26.
//

import Foundation

enum ItemNumberGenerator {
    private static let counterKey = "fliptrack.itemNumberCounter"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static func previewNextItemNumber(date: Date = Date(), defaults: UserDefaults = .standard) -> String {
        makeItemNumber(date: date, counter: defaults.integer(forKey: counterKey) + 1)
    }

    static func nextItemNumber(date: Date = Date(), defaults: UserDefaults = .standard) -> String {
        let nextCounter = defaults.integer(forKey: counterKey) + 1
        defaults.set(nextCounter, forKey: counterKey)

        return makeItemNumber(date: date, counter: nextCounter)
    }

    private static func makeItemNumber(date: Date, counter: Int) -> String {
        "RSL-\(dateFormatter.string(from: date))-\(String(format: "%04d", counter))"
    }
}
