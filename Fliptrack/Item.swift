//
//  Item.swift
//  Fliptrack
//
//  Created by Brandon Lackey on 6/12/26.
//

import Foundation
import SwiftData

enum ItemStatus: String, CaseIterable, Codable, Identifiable {
    case unlisted
    case listed
    case sold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unlisted: "Unlisted"
        case .listed: "Listed"
        case .sold: "Sold"
        }
    }
}

@Model
final class Item {
    var itemNumber: String = ""
    var brand: String?
    var category: String = ""
    var itemDescription: String = ""
    var purchasePrice: Decimal = Decimal()
    var storageLocation: String = ""
    var statusRaw: String = ItemStatus.unlisted.rawValue
    var listingPrice: Decimal?
    var platformRaw: String?
    var salePrice: Decimal?
    var platformFee: Decimal?
    var profit: Decimal?
    var dateListed: Date?
    var dateSold: Date?
    var dateCreated: Date = Date()
    var photoData: Data?
    var notes: String?

    init(
        itemNumber: String = "",
        brand: String? = nil,
        category: String = "",
        itemDescription: String = "",
        purchasePrice: Decimal = Decimal(),
        storageLocation: String = "",
        status: ItemStatus = .unlisted,
        listingPrice: Decimal? = nil,
        platformName: String? = nil,
        salePrice: Decimal? = nil,
        platformFee: Decimal? = nil,
        profit: Decimal? = nil,
        dateListed: Date? = nil,
        dateSold: Date? = nil,
        dateCreated: Date = Date(),
        photoData: Data? = nil,
        notes: String? = nil
    ) {
        self.itemNumber = itemNumber
        self.brand = brand
        self.category = category
        self.itemDescription = itemDescription
        self.purchasePrice = purchasePrice
        self.storageLocation = storageLocation
        self.statusRaw = status.rawValue
        self.listingPrice = listingPrice
        self.platformRaw = platformName
        self.salePrice = salePrice
        self.platformFee = platformFee
        self.profit = profit
        self.dateListed = dateListed
        self.dateSold = dateSold
        self.dateCreated = dateCreated
        self.photoData = photoData
        self.notes = notes
    }

    @Transient
    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .unlisted }
        set { statusRaw = newValue.rawValue }
    }

    @Transient
    var platformName: String? {
        get {
            guard let platformRaw else { return nil }
            return Self.legacyPlatformNames[platformRaw] ?? platformRaw
        }
        set { platformRaw = newValue }
    }

    private static let legacyPlatformNames = [
        "poshmark": "Poshmark",
        "ebay": "eBay",
        "mercari": "Mercari",
        "vinted": "Vinted",
        "depop": "Depop",
        "other": "Other"
    ]
}

@Model
final class SellingPlatform {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var isDefault: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        sortOrder: Int = 0,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

@Model
final class Brand {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var isDefault: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        sortOrder: Int = 0,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

@Model
final class StorageLocation {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String = "", sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
