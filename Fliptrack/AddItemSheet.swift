//
//  AddItemSheet.swift
//  Fliptrack
//
//  Created by Codex on 6/12/26.
//

import SwiftData
import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \StorageLocation.sortOrder) private var storageLocations: [StorageLocation]

    @State private var brand = ""
    @State private var category = ""
    @State private var itemDescription = ""
    @State private var purchasePrice = ""
    @State private var storageLocation = ""
    @State private var status: ItemStatus = .unlisted
    @State private var listingPrice = ""
    @State private var platform: Platform?
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Item Number")
                        Spacer()
                        Text(ItemNumberGenerator.previewNextItemNumber())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("Item") {
                    TextField("Brand", text: $brand)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $category) {
                        Text("Select").tag("")
                        ForEach(categoryOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)

                    TextField("Purchase Price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                }

                Section("Storage") {
                    Picker("Location", selection: $storageLocation) {
                        Text("Select").tag("")
                        ForEach(storageLocationOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Unlisted").tag(ItemStatus.unlisted)
                        Text("Listed").tag(ItemStatus.listed)
                    }
                    .pickerStyle(.segmented)

                    if status == .listed {
                        TextField("Listing Price", text: $listingPrice)
                            .keyboardType(.decimalPad)

                        Picker("Platform", selection: $platform) {
                            Text("Select").tag(Optional<Platform>.none)
                            ForEach(Platform.allCases) { platform in
                                Text(platform.displayName).tag(Optional(platform))
                            }
                        }

                        Text("Listing date is set automatically when you save as Listed")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.butterYellow)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveItem)
                        .disabled(isSaveDisabled)
                }
            }
            .onAppear(perform: initializeSelections)
            .onChange(of: status) { _, newStatus in
                if newStatus == .unlisted {
                    listingPrice = ""
                    platform = nil
                }
            }
        }
        .presentationDetents([.large])
    }

    private var categoryOptions: [String] {
        let seeded = categories.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        return seeded.isEmpty ? SeedData.defaultCategories : seeded
    }

    private var storageLocationOptions: [String] {
        let seeded = storageLocations.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        return seeded.isEmpty ? SeedData.defaultStorageLocations : seeded
    }

    private var isSaveDisabled: Bool {
        itemDescription.trimmed.isEmpty ||
            category.isEmpty ||
            storageLocation.isEmpty ||
            decimal(from: purchasePrice) == nil ||
            decimal(from: purchasePrice).map { $0 <= 0 } == true ||
            (status == .listed && (
                decimal(from: listingPrice) == nil ||
                    decimal(from: listingPrice).map { $0 <= 0 } == true ||
                    platform == nil
            ))
    }

    private func initializeSelections() {
        if category.isEmpty {
            category = categoryOptions.first ?? ""
        }

        if storageLocation.isEmpty {
            storageLocation = storageLocationOptions.first ?? ""
        }
    }

    private func saveItem() {
        guard let purchasePrice = decimal(from: purchasePrice) else { return }
        let now = Date()

        let item = Item(
            itemNumber: ItemNumberGenerator.nextItemNumber(date: now),
            brand: brand.trimmed.nilIfEmpty,
            category: category,
            itemDescription: itemDescription.trimmed,
            purchasePrice: purchasePrice,
            storageLocation: storageLocation,
            status: status,
            listingPrice: status == .listed ? decimal(from: listingPrice) : nil,
            platform: status == .listed ? platform : nil,
            dateListed: status == .listed ? now : nil,
            dateCreated: now,
            notes: notes.trimmed.nilIfEmpty
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Could not save item: \(error)")
        }
    }

    private func decimal(from text: String) -> Decimal? {
        let sanitized = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmed

        guard sanitized.isEmpty == false else { return nil }
        return Decimal(string: sanitized, locale: Locale.current) ?? Decimal(string: sanitized)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
