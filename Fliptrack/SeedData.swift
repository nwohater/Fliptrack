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
    private static let didSeedPlatformsKey = "fliptrack.didSeedPlatforms"

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

    static let defaultPlatforms = [
        "Poshmark",
        "eBay",
        "Mercari",
        "Vinted",
        "Depop",
        "Other"
    ]

    @MainActor
    static func seedReferenceDataIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        var didSeedReferenceData = false
        var didSeedPlatforms = false

        if defaults.bool(forKey: didSeedKey) == false {
            for (index, name) in defaultCategories.enumerated() {
                context.insert(Category(name: name, sortOrder: index, isDefault: true))
            }

            for (index, name) in defaultStorageLocations.enumerated() {
                context.insert(StorageLocation(name: name, sortOrder: index))
            }

            didSeedReferenceData = true
        }

        if defaults.bool(forKey: didSeedPlatformsKey) == false {
            for (index, name) in defaultPlatforms.enumerated() {
                context.insert(SellingPlatform(name: name, sortOrder: index, isDefault: true))
            }

            didSeedPlatforms = true
        }

        do {
            try context.save()
            if didSeedReferenceData {
                defaults.set(true, forKey: didSeedKey)
            }
            if didSeedPlatforms {
                defaults.set(true, forKey: didSeedPlatformsKey)
            }
        } catch {
            assertionFailure("Could not seed reference data: \(error)")
        }
    }
}
