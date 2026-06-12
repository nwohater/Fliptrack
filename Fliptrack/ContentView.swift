//
//  ContentView.swift
//  Fliptrack
//
//  Created by Brandon Lackey on 6/12/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RootView()
            .task {
                SeedData.seedReferenceDataIfNeeded(in: modelContext)
            }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "square.grid.2x2.fill")
                }

            ReportsPlaceholderView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }

            SettingsPlaceholderView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.hotPink)
    }
}

struct InventoryView: View {
    @Query(sort: \Item.dateCreated, order: .reverse) private var items: [Item]
    @State private var isShowingAddItem = false

    private var activeItems: [Item] {
        items.filter { $0.status != .sold }
    }

    var body: some View {
        NavigationStack {
            List {
                if activeItems.isEmpty {
                    ContentUnavailableView(
                        "No inventory yet",
                        systemImage: "tag",
                        description: Text("Add your first item to start tracking resale profit.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(activeItems) { item in
                        ItemRowView(item: item)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.butterYellow)
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem {
                    Button {
                        isShowingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.hotPink)
                    .accessibilityLabel("Add item")
                }
            }
            .sheet(isPresented: $isShowingAddItem) {
                AddItemSheet()
            }
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.itemDescription.isEmpty ? "Untitled item" : item.itemDescription)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    Text(itemSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer(minLength: 12)

                Text(priceText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
            }

            HStack {
                Text(item.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.softPink.opacity(0.55), in: Capsule())

                Spacer()

                Text(item.status.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusForeground(for: item.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusBackground(for: item.status), in: Capsule())
            }
        }
        .padding(.vertical, 6)
    }

    private var itemSubtitle: String {
        if let brand = item.brand, brand.isEmpty == false {
            "\(item.itemNumber) • \(brand)"
        } else {
            item.itemNumber
        }
    }

    private var priceText: String {
        switch item.status {
        case .unlisted:
            CurrencyFormatter.string(from: item.purchasePrice)
        case .listed:
            CurrencyFormatter.string(from: item.listingPrice)
        case .sold:
            CurrencyFormatter.string(from: item.profit)
        }
    }

    private func statusBackground(for status: ItemStatus) -> Color {
        switch status {
        case .unlisted: .butterYellow
        case .listed: .softPink
        case .sold: .electricPurple
        }
    }

    private func statusForeground(for status: ItemStatus) -> Color {
        switch status {
        case .unlisted, .listed: .primaryText
        case .sold: .white
        }
    }
}

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func string(from decimal: Decimal?) -> String {
        guard let decimal else { return "--" }
        return formatter.string(from: decimal as NSDecimalNumber) ?? "--"
    }
}

struct ReportsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Reports", systemImage: "chart.bar", description: Text("Sales reporting lands after core inventory."))
                .background(Color.butterYellow)
                .navigationTitle("Reports")
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Settings", systemImage: "gearshape", description: Text("Reference lists and sync settings land soon."))
                .background(Color.butterYellow)
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Brand.self, Category.self, StorageLocation.self], inMemory: true)
}
