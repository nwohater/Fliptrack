//
//  SeedData.swift
//  Fliptrack
//
//  Created by Codex on 6/12/26.
//

import Foundation
import SwiftData

enum SeedData {
    private static let didSeedKey = "fliptrack.didSeedReferenceData"

    static let defaultCategories = [
        "Shoes",
        "Dresses",
        "Handbags",
        "Jeans",
        "Tops",
        "Bottoms",
        "Outerwear",
        "Accessories",
        "Bags",
        "Jewelry",
        "Other"
    ]

    static let defaultStorageLocations = [
        "Closet",
        "Garage",
        "Spare Room",
        "Box 1"
    ]

    @MainActor
    static func seedReferenceDataIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: didSeedKey) == false else { return }

        for (index, name) in defaultCategories.enumerated() {
            context.insert(Category(name: name, sortOrder: index, isDefault: true))
        }

        for (index, name) in defaultStorageLocations.enumerated() {
            context.insert(StorageLocation(name: name, sortOrder: index))
        }

        do {
            try context.save()
            defaults.set(true, forKey: didSeedKey)
        } catch {
            assertionFailure("Could not seed reference data: \(error)")
        }
    }
}
