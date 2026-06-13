//
//  ContentView.swift
//  Fliptrack
//
//  Created by Brandon Lackey on 6/12/26.
//

import SwiftData
import SwiftUI
import UIKit
import LinkPresentation

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

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.hotPink)
    }
}

struct AppHeader: View {
    var addAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            AppBrandText()

            Spacer()

            if let addAction {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.hotPink, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add item")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}

struct AppBrandText: View {
    var body: some View {
        (
            Text("flip")
                .foregroundStyle(Color.hotPink)
            + Text("track")
                .foregroundStyle(Color.electricPurple)
        )
            .font(.title2.weight(.heavy))
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("fliptrack")
    }
}

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.dateCreated, order: .reverse) private var items: [Item]
    @State private var isShowingAddItem = false
    @State private var itemToList: Item?
    @State private var itemToMarkSold: Item?
    @State private var itemToEdit: Item?
    @State private var itemToDelete: Item?
    @State private var itemToUnlist: Item?
    @State private var searchText = ""
    @State private var selectedFilter: InventoryFilter = .active

    private var visibleItems: [Item] {
        items
            .filter(matchesSelectedFilter)
            .filter(matchesSearch)
    }

    private var soldItemsInScope: [Item] {
        visibleItems.filter { $0.status == .sold }
    }

    private var soldNetProfit: Decimal {
        soldItemsInScope.reduce(Decimal()) { total, item in
            total + (item.profit ?? Decimal())
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                AppHeader {
                    isShowingAddItem = true
                }

                InventorySearchBar(text: $searchText)
                    .padding(.horizontal)

                InventoryFilterControl(selection: $selectedFilter)
                    .padding(.horizontal)

                if selectedFilter == .sold, soldItemsInScope.isEmpty == false {
                    SoldSummaryStrip(itemCount: soldItemsInScope.count, netProfit: soldNetProfit)
                        .padding(.horizontal)
                }

                List {
                    if visibleItems.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(visibleItems) { item in
                            ItemRowView(item: item)
                                .onTapGesture {
                                    itemToEdit = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }

                                    if item.status == .unlisted {
                                        Button {
                                            itemToList = item
                                        } label: {
                                            Label("List It", systemImage: "tag.fill")
                                        }
                                        .tint(.hotPink)
                                    }

                                    if item.status == .listed {
                                        Button {
                                            itemToUnlist = item
                                        } label: {
                                            Label("Unlist", systemImage: "arrow.uturn.backward.circle.fill")
                                        }
                                        .tint(.softPink)

                                        Button {
                                            itemToMarkSold = item
                                        } label: {
                                            Label("Mark Sold", systemImage: "dollarsign.circle.fill")
                                        }
                                        .tint(.electricPurple)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color.butterYellow.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingAddItem) {
                AddItemSheet()
            }
            .sheet(item: $itemToList) { item in
                ListItSheet(item: item)
            }
            .sheet(item: $itemToMarkSold) { item in
                MarkAsSoldSheet(item: item)
            }
            .sheet(item: $itemToEdit) { item in
                EditItemSheet(item: item)
            }
            .confirmationDialog(
                "Unlist Item?",
                isPresented: Binding(
                    get: { itemToUnlist != nil },
                    set: { isPresented in
                        if isPresented == false {
                            itemToUnlist = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Move to Unlisted") {
                    unlistSelectedItem()
                }

                Button("Cancel", role: .cancel) {
                    itemToUnlist = nil
                }
            } message: {
                Text("This clears the listing price, platforms, and listing date.")
            }
            .confirmationDialog(
                "Delete Item?",
                isPresented: Binding(
                    get: { itemToDelete != nil },
                    set: { isPresented in
                        if isPresented == false {
                            itemToDelete = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Item", role: .destructive) {
                    deleteSelectedItem()
                }

                Button("Cancel", role: .cancel) {
                    itemToDelete = nil
                }
            } message: {
                Text("This removes the item from inventory and cannot be undone.")
            }
        }
    }

    private var emptyState: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No inventory yet",
                    systemImage: "tag",
                    description: Text("Add your first item to start tracking resale profit.")
                )
            } else if searchText.trimmed.isEmpty == false {
                ContentUnavailableView(
                    "No matching items",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different item number, description, brand, or category.")
                )
            } else if selectedFilter == .sold {
                ContentUnavailableView(
                    "Nothing sold yet",
                    systemImage: "sparkles",
                    description: Text("Sold items will show here when you mark them sold.")
                )
            } else {
                ContentUnavailableView(
                    "No \(selectedFilter.title.lowercased()) items",
                    systemImage: selectedFilter.systemImage,
                    description: Text("Items in this status will show here.")
                )
            }
        }
    }

    private func matchesSelectedFilter(_ item: Item) -> Bool {
        switch selectedFilter {
        case .active:
            item.status != .sold
        case .all:
            true
        case .unlisted:
            item.status == .unlisted
        case .listed:
            item.status == .listed
        case .sold:
            item.status == .sold
        }
    }

    private func matchesSearch(_ item: Item) -> Bool {
        let query = searchText.trimmed
        guard query.isEmpty == false else { return true }

        return [
            item.itemNumber,
            item.itemDescription,
            item.brand ?? "",
            item.category,
        ].contains { value in
            value.localizedCaseInsensitiveContains(query)
        }
    }

    private func deleteSelectedItem() {
        guard let itemToDelete else { return }

        modelContext.delete(itemToDelete)
        self.itemToDelete = nil

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not delete item: \(error)")
        }
    }

    private func unlistSelectedItem() {
        guard let itemToUnlist else { return }

        itemToUnlist.status = .unlisted
        itemToUnlist.listingPrice = nil
        itemToUnlist.listingPlatformsRaw = nil
        itemToUnlist.dateListed = nil
        self.itemToUnlist = nil

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not unlist item: \(error)")
        }
    }
}

struct ListItSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SellingPlatform.sortOrder) private var sellingPlatforms: [SellingPlatform]

    let item: Item
    @State private var listingPrice = ""
    @State private var selectedPlatforms: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("List This Item")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.primaryText)

                        Text("\(item.itemNumber) | \(item.itemDescription)")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.white)

                Section("Listing Price") {
                    CurrencyTextField(label: "Listing Price", text: $listingPrice)
                        .font(.title3.weight(.bold))
                }
                .listRowBackground(Color.white)

                Section("Platforms (select all that apply)") {
                    ForEach(platformOptions, id: \.self) { name in
                        Button {
                            if selectedPlatforms.contains(name) {
                                selectedPlatforms.remove(name)
                            } else {
                                selectedPlatforms.insert(name)
                            }
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                if selectedPlatforms.contains(name) {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.hotPink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.white)

                Section {
                    Button(action: listItem) {
                        Text("List It")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isConfirmDisabled)
                    .listRowBackground(Color.hotPink)
                    .foregroundStyle(.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.butterYellow)
            .navigationTitle("List Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if listingPrice.isEmpty, let existingPrice = item.listingPrice {
                    listingPrice = CurrencyFormatter.string(from: existingPrice)
                }

                if selectedPlatforms.isEmpty {
                    selectedPlatforms = Set(item.listingPlatforms)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var platformOptions: [String] {
        let seeded = sellingPlatforms.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        let base = seeded.isEmpty ? SeedData.defaultPlatforms : seeded
        let extras = selectedPlatforms.filter { base.contains($0) == false }.sorted()
        return extras + base
    }

    private var isConfirmDisabled: Bool {
        decimal(from: listingPrice).map { $0 > 0 } != true || selectedPlatforms.isEmpty
    }

    private func listItem() {
        guard let listingPrice = decimal(from: listingPrice), selectedPlatforms.isEmpty == false else { return }

        item.status = .listed
        item.listingPrice = listingPrice
        item.listingPlatforms = Array(selectedPlatforms)
        item.dateListed = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Could not list item: \(error)")
        }
    }
}

struct MarkAsSoldSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: Item
    @State private var salePrice = ""
    @State private var platformFee = ""
    @State private var soldPlatform = ""

    private var parsedSalePrice: Decimal? {
        decimal(from: salePrice)
    }

    private var parsedPlatformFee: Decimal? {
        if platformFee.trimmed.isEmpty {
            return nil
        }

        return decimal(from: platformFee)
    }

    private var liveProfit: Decimal? {
        guard let parsedSalePrice, let parsedPlatformFee else { return nil }
        return parsedSalePrice - item.purchasePrice - parsedPlatformFee
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mark as Sold")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.primaryText)

                        Text(item.itemDescription)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.white)

                Section("Sale") {
                    CurrencyTextField(label: "Sale Price", text: $salePrice)

                    CurrencyTextField(label: "Platform Fee", text: $platformFee, color: Color.lossRed)
                }
                .listRowBackground(Color.white)

                if item.listingPlatforms.isEmpty == false {
                    Section("Sold On") {
                        Picker("Platform", selection: $soldPlatform) {
                            Text("Select").tag("")
                            ForEach(item.listingPlatforms, id: \.self) { platform in
                                Text(platform).tag(platform)
                            }
                        }
                    }
                    .listRowBackground(Color.white)
                }

                if let liveProfit {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net Profit")
                                    .font(.caption.weight(.bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.white.opacity(0.8))

                                Text(CurrencyFormatter.signedString(from: liveProfit))
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(.white)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(
                        LinearGradient(
                            colors: profitGradientColors(for: liveProfit),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }

                Section {
                    Button(action: markSold) {
                        Text("Confirm Sale")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isConfirmDisabled)
                    .listRowBackground(Color.electricPurple)
                    .foregroundStyle(.white)

                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.butterYellow)
            .navigationTitle("Mark Sold")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if salePrice.isEmpty, let listingPrice = item.listingPrice {
                    salePrice = CurrencyFormatter.string(from: listingPrice)
                }
                if soldPlatform.isEmpty && item.listingPlatforms.count == 1 {
                    soldPlatform = item.listingPlatforms[0]
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isConfirmDisabled: Bool {
        parsedSalePrice.map { $0 > 0 } != true ||
            parsedPlatformFee.map { $0 >= 0 } != true ||
            (item.listingPlatforms.isEmpty == false && soldPlatform.isEmpty)
    }

    private func markSold() {
        guard let parsedSalePrice, let parsedPlatformFee, let liveProfit else { return }

        item.status = .sold
        item.salePrice = parsedSalePrice
        item.platformFee = parsedPlatformFee
        item.profit = liveProfit
        item.soldPlatformName = soldPlatform.isEmpty ? nil : soldPlatform
        item.dateSold = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Could not mark item sold: \(error)")
        }
    }

    private func profitGradientColors(for profit: Decimal) -> [Color] {
        if profit < 0 {
            [.lossRed, .hotPink]
        } else {
            [.profitGreen, .electricPurple]
        }
    }
}

enum InventoryFilter: String, CaseIterable, Identifiable {
    case active
    case all
    case unlisted
    case listed
    case sold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "Active"
        case .all: "All"
        case .unlisted: "Unlisted"
        case .listed: "Listed"
        case .sold: "Sold"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "tag"
        case .all: "tray.full"
        case .unlisted: "square.and.pencil"
        case .listed: "checkmark.seal"
        case .sold: "dollarsign.circle"
        }
    }
}

struct InventorySearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("Search items, brands...", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if text.isEmpty == false {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

struct InventoryFilterControl: View {
    @Binding var selection: InventoryFilter

    private var filters: [InventoryFilter] {
        [.all, .unlisted, .listed, .sold]
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(filters) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selection == filter ? Color.primaryText : Color.primaryText.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if selection == filter {
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == filter ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.softPink.opacity(0.32), in: Capsule())
    }
}

struct SoldSummaryStrip: View {
    let itemCount: Int
    let netProfit: Decimal

    var body: some View {
        HStack {
            Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                .font(.subheadline.weight(.bold))

            Spacer()

            Text("NET PROFIT \(CurrencyFormatter.signedString(from: netProfit))")
                .font(.subheadline.weight(.heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(
            LinearGradient(
                colors: [.electricPurple, .hotPink],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .shadow(color: Color.electricPurple.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ItemThumbnailView(item: item)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.itemDescription.isEmpty ? "Untitled item" : item.itemDescription)
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(2)

                        Text(itemSubtitle)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(priceText)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(priceColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        StatusBadge(status: item.status)
                    }
                }

                HStack {
                    Text(item.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.softPink.opacity(0.55), in: Capsule())

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var itemSubtitle: String {
        if let brand = item.brand, brand.isEmpty == false {
            "\(item.itemNumber) | \(brand)"
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
            CurrencyFormatter.signedString(from: item.profit)
        }
    }

    private var priceColor: Color {
        guard item.status == .sold, let profit = item.profit else {
            return .primaryText
        }

        return profit < 0 ? .lossRed : .profitGreen
    }
}

struct ItemThumbnailView: View {
    let item: Item

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.softPink.opacity(0.85), Color.butterYellow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: categoryIcon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.electricPurple)
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private var image: UIImage? {
        guard let photoData = item.photoData else { return nil }
        return UIImage(data: photoData)
    }

    private var categoryIcon: String {
        switch item.category.lowercased() {
        case let value where value.contains("shoe"):
            "shoe.2.fill"
        case let value where value.contains("bag") || value.contains("handbag"):
            "handbag.fill"
        case let value where value.contains("jewelry"):
            "sparkles"
        case let value where value.contains("outerwear"):
            "tshirt.fill"
        case let value where value.contains("dress") || value.contains("top") || value.contains("bottom") || value.contains("jean"):
            "tshirt.fill"
        default:
            "tag.fill"
        }
    }
}

struct StatusBadge: View {
    let status: ItemStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(statusForeground)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(statusBackground, in: Capsule())
            .overlay {
                if status == .unlisted {
                    Capsule()
                        .stroke(Color.primaryText.opacity(0.14), lineWidth: 1)
                }
            }
            .accessibilityLabel("\(status.displayName) status")
    }

    private var statusBackground: Color {
        switch status {
        case .unlisted: .butterYellow
        case .listed: .softPink
        case .sold: .electricPurple
        }
    }

    private var statusForeground: Color {
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

    static func signedString(from decimal: Decimal?) -> String {
        guard let decimal else { return "--" }
        let sign = decimal >= 0 ? "+" : ""
        return "\(sign)\(string(from: decimal))"
    }

    static func editingString(from decimal: Decimal) -> String {
        let number = decimal as NSDecimalNumber
        return number.decimalValue.description
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

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ReportsView: View {
    @Query(sort: \Item.dateCreated, order: .reverse) private var items: [Item]
    @State private var selectedTimeFilter: ReportsTimeFilter = .allTime
    @State private var itemToEdit: Item?

    private var soldItems: [Item] {
        items
            .filter { $0.status == .sold }
            .sorted { lhs, rhs in
                (lhs.dateSold ?? lhs.dateCreated) > (rhs.dateSold ?? rhs.dateCreated)
            }
    }

    private var filteredSoldItems: [Item] {
        soldItems.filter { item in
            selectedTimeFilter.contains(item.dateSold ?? item.dateCreated)
        }
    }

    private var listedItems: [Item] {
        items.filter { $0.status == .listed }
    }

    private var activeItems: [Item] {
        items.filter { $0.status != .sold }
    }

    private var totalRevenue: Decimal {
        filteredSoldItems.reduce(Decimal()) { total, item in
            total + (item.salePrice ?? Decimal())
        }
    }

    private var totalFees: Decimal {
        filteredSoldItems.reduce(Decimal()) { total, item in
            total + (item.platformFee ?? Decimal())
        }
    }

    private var totalProfit: Decimal {
        filteredSoldItems.reduce(Decimal()) { total, item in
            total + (item.profit ?? Decimal())
        }
    }

    private var profitMarginText: String {
        guard totalRevenue > 0 else { return "--" }
        let margin = (totalProfit as NSDecimalNumber)
            .dividing(by: totalRevenue as NSDecimalNumber)
            .doubleValue
        return ReportFormatters.percent.string(from: NSNumber(value: margin)) ?? "--"
    }

    private var activeCost: Decimal {
        activeItems.reduce(Decimal()) { total, item in
            total + item.purchasePrice
        }
    }

    private var listedValue: Decimal {
        listedItems.reduce(Decimal()) { total, item in
            total + (item.listingPrice ?? Decimal())
        }
    }

    private var averageProfit: Decimal? {
        guard filteredSoldItems.isEmpty == false else { return nil }
        return (totalProfit as NSDecimalNumber)
            .dividing(by: NSDecimalNumber(value: filteredSoldItems.count))
            .decimalValue
    }

    private var sellThroughText: String {
        guard items.isEmpty == false else { return "0%" }
        let rate = Double(filteredSoldItems.count) / Double(items.count)
        return ReportFormatters.percent.string(from: NSNumber(value: rate)) ?? "0%"
    }

    private var shareCardData: ReportShareCardData {
        ReportShareCardData(
            periodTitle: selectedTimeFilter.title,
            netProfit: CurrencyFormatter.signedString(from: totalProfit),
            profitMargin: profitMarginText,
            revenue: CurrencyFormatter.string(from: totalRevenue),
            soldCount: "\(filteredSoldItems.count)",
            averageProfit: CurrencyFormatter.string(from: averageProfit),
            feesPaid: CurrencyFormatter.string(from: totalFees),
            sellThrough: sellThroughText,
            activeCost: CurrencyFormatter.string(from: activeCost),
            listedValue: CurrencyFormatter.string(from: listedValue),
            recentSales: filteredSoldItems.prefix(3).map { item in
                let description = item.itemDescription.isEmpty ? "Untitled item" : item.itemDescription
                return ReportShareSale(description: description, profit: CurrencyFormatter.signedString(from: item.profit))
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ReportsHeader {
                        exportReportCard()
                    }

                    if items.isEmpty {
                        ContentUnavailableView(
                            "No reports yet",
                            systemImage: "chart.bar",
                            description: Text("Add inventory and mark items sold to build your first report.")
                        )
                        .padding(.top, 80)
                    } else {
                        ReportsTimeFilterControl(selection: $selectedTimeFilter)
                            .padding(.horizontal)

                        ReportsProfitHeader(
                            netProfit: totalProfit,
                            revenue: totalRevenue,
                            soldCount: filteredSoldItems.count,
                            sellThrough: sellThroughText,
                            profitMargin: profitMarginText
                        )
                        .padding(.horizontal)

                        ReportExportPreviewCard(
                            timeFilterTitle: selectedTimeFilter.title,
                            netProfit: totalProfit,
                            revenue: totalRevenue,
                            profitMargin: profitMarginText,
                            soldCount: filteredSoldItems.count
                        )
                        .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ReportMetricCard(
                                title: "Inventory Cost",
                                value: CurrencyFormatter.string(from: activeCost),
                                subtitle: "\(activeItems.count) active",
                                systemImage: "shippingbox.fill",
                                tint: .electricPurple
                            )

                            ReportMetricCard(
                                title: "Listed Value",
                                value: CurrencyFormatter.string(from: listedValue),
                                subtitle: "\(listedItems.count) listed",
                                systemImage: "tag.fill",
                                tint: .hotPink
                            )

                            ReportMetricCard(
                                title: "Fees Paid",
                                value: CurrencyFormatter.string(from: totalFees),
                                subtitle: "platform fees",
                                systemImage: "minus.circle.fill",
                                tint: .lossRed
                            )

                            ReportMetricCard(
                                title: "Avg Profit",
                                value: CurrencyFormatter.string(from: averageProfit),
                                subtitle: "per sold item",
                                systemImage: "chart.line.uptrend.xyaxis",
                                tint: .profitGreen
                            )

                            ReportMetricCard(
                                title: "Profit Margin",
                                value: profitMarginText,
                                subtitle: selectedTimeFilter.title.lowercased(),
                                systemImage: "percent",
                                tint: .electricPurple
                            )

                            ReportMetricCard(
                                title: "Sell-through",
                                value: sellThroughText,
                                subtitle: selectedTimeFilter.title.lowercased(),
                                systemImage: "arrow.up.forward.circle.fill",
                                tint: .hotPink
                            )
                        }
                        .padding(.horizontal)

                        InventoryStatusBreakdown(
                            unlistedCount: items.filter { $0.status == .unlisted }.count,
                            listedCount: listedItems.count,
                            soldCount: soldItems.count
                        )
                        .padding(.horizontal)

                        RecentSalesSection(items: Array(filteredSoldItems.prefix(5))) { item in
                            itemToEdit = item
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 110)
            }
            .background(Color.butterYellow.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $itemToEdit) { item in
                EditItemSheet(item: item)
            }
        }
    }

    private func exportReportCard() {
        let card = ReportShareImageCard(data: shareCardData)
            .frame(width: 390)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            ReportSharePresenter.present(image: image, title: "fliptrack \(selectedTimeFilter.title) report")
        }
    }
}

struct ReportsHeader: View {
    let exportAction: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            AppBrandText()

            Spacer()

            Button(action: exportAction) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.electricPurple, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export report summary")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}

struct ReportShareCardData {
    let periodTitle: String
    let netProfit: String
    let profitMargin: String
    let revenue: String
    let soldCount: String
    let averageProfit: String
    let feesPaid: String
    let sellThrough: String
    let activeCost: String
    let listedValue: String
    let recentSales: [ReportShareSale]
}

struct ReportShareSale: Identifiable {
    let id = UUID()
    let description: String
    let profit: String
}

struct ReportShareImageCard: View {
    let data: ReportShareCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    (
                        Text("flip")
                            .foregroundStyle(Color.hotPink)
                        + Text("track")
                            .foregroundStyle(Color.electricPurple)
                    )
                    .font(.title2.weight(.heavy))

                    Text(data.periodTitle)
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.primaryText.opacity(0.58))
                }

                Spacer()

                Image(systemName: "chart.bar.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.hotPink, in: Circle())
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Net Profit")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.78))

                Text(data.netProfit)
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                HStack(spacing: 14) {
                    ShareCardPill(title: "Revenue", value: data.revenue)
                    ShareCardPill(title: "Margin", value: data.profitMargin)
                    ShareCardPill(title: "Sold", value: data.soldCount)
                }
            }
            .padding(18)
            .background(
                LinearGradient(colors: [.profitGreen, .electricPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22)
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ShareCardMetric(title: "Avg Profit", value: data.averageProfit, tint: .profitGreen)
                ShareCardMetric(title: "Fees Paid", value: data.feesPaid, tint: .lossRed)
                ShareCardMetric(title: "Active Cost", value: data.activeCost, tint: .electricPurple)
                ShareCardMetric(title: "Listed Value", value: data.listedValue, tint: .hotPink)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent Sales")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.primaryText)

                    Spacer()

                    Text(data.sellThrough)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color.hotPink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.softPink.opacity(0.45), in: Capsule())
                }

                if data.recentSales.isEmpty {
                    Text("No sales in this period yet.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(data.recentSales) { sale in
                        HStack(spacing: 10) {
                            Text(sale.description)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.primaryText)
                                .lineLimit(1)

                            Spacer()

                            Text(sale.profit)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(sale.profit.hasPrefix("-") ? Color.lossRed : Color.profitGreen)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(14)
            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))

            Text("shared from fliptrack")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(22)
        .background(Color.butterYellow)
    }
}

struct ShareCardPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShareCardMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 12)
        }
    }
}

final class ReportActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

enum ReportSharePresenter {
    static func present(image: UIImage, title: String) {
        guard let presenter = UIApplication.shared.topViewController else { return }

        let itemSource = ReportActivityItemSource(image: image, title: title)
        let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)

        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.sourceView = presenter.view
            popoverPresentationController.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.minY + 72,
                width: 0,
                height: 0
            )
            popoverPresentationController.permittedArrowDirections = []
        }

        presenter.present(activityViewController, animated: true)
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        guard
            let windowScene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let rootViewController = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            return nil
        }

        return rootViewController.topPresentedViewController
    }
}

private extension UIViewController {
    var topPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topPresentedViewController
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topPresentedViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topPresentedViewController
        }

        return self
    }
}

enum ReportsTimeFilter: String, CaseIterable, Identifiable {
    case allTime
    case thisYear
    case thisMonth
    case last30Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allTime: "All Time"
        case .thisYear: "This Year"
        case .thisMonth: "This Month"
        case .last30Days: "Last 30 Days"
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> Bool {
        switch self {
        case .allTime:
            return true
        case .thisYear:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .last30Days:
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= startDate && date <= now
        }
    }
}

struct ReportsTimeFilterControl: View {
    @Binding var selection: ReportsTimeFilter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ReportsTimeFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selection == filter ? Color.primaryText : Color.primaryText.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if selection == filter {
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == filter ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.softPink.opacity(0.32), in: Capsule())
    }
}

struct ReportsProfitHeader: View {
    let netProfit: Decimal
    let revenue: Decimal
    let soldCount: Int
    let sellThrough: String
    let profitMargin: String

    private var profitColors: [Color] {
        netProfit < 0 ? [.lossRed, .hotPink] : [.profitGreen, .electricPurple]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Net Profit")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.78))

                    Text(CurrencyFormatter.signedString(from: netProfit))
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                Image(systemName: "sparkline")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
            }

            HStack(spacing: 12) {
                ReportPill(title: "Revenue", value: CurrencyFormatter.string(from: revenue))
                ReportPill(title: "Sold", value: "\(soldCount)")
                ReportPill(title: "Margin", value: profitMargin)
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: profitColors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .shadow(color: Color.electricPurple.opacity(0.22), radius: 14, x: 0, y: 8)
    }
}

struct ReportExportPreviewCard: View {
    let timeFilterTitle: String
    let netProfit: Decimal
    let revenue: Decimal
    let profitMargin: String
    let soldCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share Summary")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.secondaryText)

                    Text(timeFilterTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.primaryText)
                }

                Spacer()

                Image(systemName: "message.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.hotPink)
            }

            HStack(spacing: 12) {
                ShareSummaryMetric(title: "Profit", value: CurrencyFormatter.signedString(from: netProfit))
                ShareSummaryMetric(title: "Margin", value: profitMargin)
                ShareSummaryMetric(title: "Sold", value: "\(soldCount)")
            }

            Text("Revenue \(CurrencyFormatter.string(from: revenue))")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(14)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.softPink.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct ShareSummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReportPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))

            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReportMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.primaryText.opacity(0.72))

                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct InventoryStatusBreakdown: View {
    let unlistedCount: Int
    let listedCount: Int
    let soldCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.primaryText)

            HStack(spacing: 8) {
                StatusCountPill(title: "Unlisted", count: unlistedCount, tint: .softPink)
                StatusCountPill(title: "Listed", count: listedCount, tint: .hotPink)
                StatusCountPill(title: "Sold", count: soldCount, tint: .electricPurple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusCountPill: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Text("\(count)")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.primaryText)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.primaryText.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RecentSalesSection: View {
    let items: [Item]
    var onTap: ((Item) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sales")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.primaryText)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.electricPurple)

                    Text("Sold items will show here.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        RecentSaleRow(item: item)
                            .onTapGesture { onTap?(item) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentSaleRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            ItemThumbnailView(item: item)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.itemDescription.isEmpty ? "Untitled item" : item.itemDescription)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)

                Text(saleDetail)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Text(CurrencyFormatter.signedString(from: item.profit))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle((item.profit ?? Decimal()) < 0 ? Color.lossRed : Color.profitGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.5))
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 9, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var saleDetail: String {
        let soldDate = item.dateSold.map { ReportFormatters.shortDate.string(from: $0) } ?? "No sale date"
        return "\(CurrencyFormatter.string(from: item.salePrice)) | \(soldDate)"
    }
}

enum ReportFormatters {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Brand.name) private var brands: [Brand]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \StorageLocation.sortOrder) private var storageLocations: [StorageLocation]
    @Query(sort: \SellingPlatform.sortOrder) private var sellingPlatforms: [SellingPlatform]

    @State private var newBrand = ""
    @State private var newCategory = ""
    @State private var newStorageLocation = ""
    @State private var newPlatform = ""
    @State private var editTarget: SettingsEditTarget?
    @State private var editName = ""
    @State private var deleteTarget: SettingsEditTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AppHeader()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.primaryText)

                        Text("Keep the picker lists tidy for faster item entry.")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    ReferenceListCard(
                        title: "Brands",
                        subtitle: "Optional labels for item makers and designers.",
                        systemImage: "sparkles",
                        tint: .hotPink,
                        newName: $newBrand,
                        placeholder: "Add brand",
                        rows: brandRows,
                        isAddDisabled: isDuplicate(newBrand, in: brands.map(\.name))
                    ) {
                        addBrand()
                    } onEdit: { target in
                        beginEditing(target)
                    } onDelete: { target in
                        deleteTarget = target
                    }
                    .padding(.horizontal)

                    ReferenceListCard(
                        title: "Categories",
                        subtitle: "Used by Add Item, Edit Item, filters, and thumbnails.",
                        systemImage: "square.grid.2x2.fill",
                        tint: .electricPurple,
                        newName: $newCategory,
                        placeholder: "Add category",
                        rows: categoryRows,
                        isAddDisabled: isDuplicate(newCategory, in: categories.map(\.name))
                    ) {
                        addCategory()
                    } onEdit: { target in
                        beginEditing(target)
                    } onDelete: { target in
                        deleteTarget = target
                    }
                    .padding(.horizontal)

                    ReferenceListCard(
                        title: "Platforms",
                        subtitle: "Places where listed and sold items are tracked.",
                        systemImage: "tag.fill",
                        tint: .hotPink,
                        newName: $newPlatform,
                        placeholder: "Add platform",
                        rows: platformRows,
                        isAddDisabled: isDuplicate(newPlatform, in: sellingPlatforms.map(\.name))
                    ) {
                        addPlatform()
                    } onEdit: { target in
                        beginEditing(target)
                    } onDelete: { target in
                        deleteTarget = target
                    }
                    .padding(.horizontal)

                    ReferenceListCard(
                        title: "Storage",
                        subtitle: "Closets, bins, rooms, shelves, or anything you search by.",
                        systemImage: "shippingbox.fill",
                        tint: .profitGreen,
                        newName: $newStorageLocation,
                        placeholder: "Add location",
                        rows: storageRows,
                        isAddDisabled: isDuplicate(newStorageLocation, in: storageLocations.map(\.name))
                    ) {
                        addStorageLocation()
                    } onEdit: { target in
                        beginEditing(target)
                    } onDelete: { target in
                        deleteTarget = target
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 110)
            }
            .background(Color.butterYellow.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Rename \(editTarget?.kind.title ?? "Item")", isPresented: isEditingReference) {
                TextField("Name", text: $editName)
                    .textInputAutocapitalization(.words)

                Button("Save") {
                    saveEdit()
                }
                .disabled(editName.trimmed.isEmpty)

                Button("Cancel", role: .cancel) {
                    editTarget = nil
                    editName = ""
                }
            }
            .confirmationDialog(
                "Delete \(deleteTarget?.name ?? "Item")?",
                isPresented: isDeletingReference,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteReference()
                }

                Button("Cancel", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                Text("Existing inventory keeps its saved text, but this option will disappear from future pickers.")
            }
        }
    }

    private var isEditingReference: Binding<Bool> {
        Binding(
            get: { editTarget != nil },
            set: { isPresented in
                if isPresented == false {
                    editTarget = nil
                    editName = ""
                }
            }
        )
    }

    private var isDeletingReference: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { isPresented in
                if isPresented == false {
                    deleteTarget = nil
                }
            }
        )
    }

    private var brandRows: [ReferenceRowData] {
        brands.map { brand in
            ReferenceRowData(
                target: SettingsEditTarget(kind: .brand, id: brand.id, name: brand.name),
                detail: nil,
                showsDefaultBadge: false
            )
        }
    }

    private var categoryRows: [ReferenceRowData] {
        categories
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { category in
                ReferenceRowData(
                    target: SettingsEditTarget(kind: .category, id: category.id, name: category.name),
                    detail: category.isDefault ? "Seeded" : nil,
                    showsDefaultBadge: category.isDefault
                )
            }
    }

    private var storageRows: [ReferenceRowData] {
        storageLocations
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { storageLocation in
                ReferenceRowData(
                    target: SettingsEditTarget(kind: .storage, id: storageLocation.id, name: storageLocation.name),
                    detail: nil,
                    showsDefaultBadge: false
                )
            }
    }

    private var platformRows: [ReferenceRowData] {
        sellingPlatforms
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { platform in
                ReferenceRowData(
                    target: SettingsEditTarget(kind: .platform, id: platform.id, name: platform.name),
                    detail: platform.isDefault ? "Seeded" : nil,
                    showsDefaultBadge: platform.isDefault
                )
            }
    }

    private func beginEditing(_ target: SettingsEditTarget) {
        editTarget = target
        editName = target.name
    }

    private func addBrand() {
        let name = newBrand.trimmed
        guard name.isEmpty == false, isDuplicate(name, in: brands.map(\.name)) == false else { return }
        modelContext.insert(Brand(name: name))
        newBrand = ""
        saveContext()
    }

    private func addCategory() {
        let name = newCategory.trimmed
        guard name.isEmpty == false, isDuplicate(name, in: categories.map(\.name)) == false else { return }
        let nextSortOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(Category(name: name, sortOrder: nextSortOrder))
        newCategory = ""
        saveContext()
    }

    private func addStorageLocation() {
        let name = newStorageLocation.trimmed
        guard name.isEmpty == false, isDuplicate(name, in: storageLocations.map(\.name)) == false else { return }
        let nextSortOrder = (storageLocations.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(StorageLocation(name: name, sortOrder: nextSortOrder))
        newStorageLocation = ""
        saveContext()
    }

    private func addPlatform() {
        let name = newPlatform.trimmed
        guard name.isEmpty == false, isDuplicate(name, in: sellingPlatforms.map(\.name)) == false else { return }
        let nextSortOrder = (sellingPlatforms.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(SellingPlatform(name: name, sortOrder: nextSortOrder))
        newPlatform = ""
        saveContext()
    }

    private func saveEdit() {
        guard let editTarget else { return }
        let name = editName.trimmed
        guard name.isEmpty == false else { return }

        switch editTarget.kind {
        case .brand:
            guard isDuplicate(name, in: brands.filter { $0.id != editTarget.id }.map(\.name)) == false,
                  let brand = brands.first(where: { $0.id == editTarget.id }) else { return }
            brand.name = name
        case .category:
            guard isDuplicate(name, in: categories.filter { $0.id != editTarget.id }.map(\.name)) == false,
                  let category = categories.first(where: { $0.id == editTarget.id }) else { return }
            category.name = name
        case .storage:
            guard isDuplicate(name, in: storageLocations.filter { $0.id != editTarget.id }.map(\.name)) == false,
                  let storageLocation = storageLocations.first(where: { $0.id == editTarget.id }) else { return }
            storageLocation.name = name
        case .platform:
            guard isDuplicate(name, in: sellingPlatforms.filter { $0.id != editTarget.id }.map(\.name)) == false,
                  let platform = sellingPlatforms.first(where: { $0.id == editTarget.id }) else { return }
            platform.name = name
        }

        self.editTarget = nil
        editName = ""
        saveContext()
    }

    private func deleteReference() {
        guard let deleteTarget else { return }

        switch deleteTarget.kind {
        case .brand:
            if let brand = brands.first(where: { $0.id == deleteTarget.id }) {
                modelContext.delete(brand)
            }
        case .category:
            if let category = categories.first(where: { $0.id == deleteTarget.id }) {
                modelContext.delete(category)
            }
        case .storage:
            if let storageLocation = storageLocations.first(where: { $0.id == deleteTarget.id }) {
                modelContext.delete(storageLocation)
            }
        case .platform:
            if let platform = sellingPlatforms.first(where: { $0.id == deleteTarget.id }) {
                modelContext.delete(platform)
            }
        }

        self.deleteTarget = nil
        saveContext()
    }

    private func isDuplicate(_ name: String, in names: [String]) -> Bool {
        let trimmedName = name.trimmed
        guard trimmedName.isEmpty == false else { return true }
        return names.contains { $0.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not save settings: \(error)")
        }
    }
}

enum SettingsReferenceKind {
    case brand
    case category
    case storage
    case platform

    var title: String {
        switch self {
        case .brand: "Brand"
        case .category: "Category"
        case .storage: "Storage"
        case .platform: "Platform"
        }
    }
}

struct SettingsEditTarget: Identifiable, Equatable {
    let kind: SettingsReferenceKind
    let id: UUID
    let name: String
}

struct ReferenceRowData: Identifiable {
    let target: SettingsEditTarget
    let detail: String?
    let showsDefaultBadge: Bool

    var id: String {
        "\(target.kind)-\(target.id)"
    }
}

struct ReferenceListCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @Binding var newName: String
    let placeholder: String
    let rows: [ReferenceRowData]
    let isAddDisabled: Bool
    let onAdd: () -> Void
    let onEdit: (SettingsEditTarget) -> Void
    let onDelete: (SettingsEditTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.primaryText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                TextField(placeholder, text: $newName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit {
                        if isAddDisabled == false {
                            onAdd()
                        }
                    }

                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isAddDisabled ? Color.secondaryText.opacity(0.45) : tint)
                }
                .buttonStyle(.plain)
                .disabled(isAddDisabled)
                .accessibilityLabel("Add \(title.lowercased())")
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.butterYellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            if rows.isEmpty {
                Text("No \(title.lowercased()) yet.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        ReferenceRow(row: row, tint: tint, onEdit: onEdit, onDelete: onDelete)

                        if row.id != rows.last?.id {
                            Divider()
                                .padding(.leading, 8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct ReferenceRow: View {
    let row: ReferenceRowData
    let tint: Color
    let onEdit: (SettingsEditTarget) -> Void
    let onDelete: (SettingsEditTarget) -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(row.target.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)

                    if row.showsDefaultBadge {
                        Text("Default")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                }

                if let detail = row.detail {
                    Text(detail)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Spacer()

            Button {
                onEdit(row.target)
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(row.target.name)")

            Button(role: .destructive) {
                onDelete(row.target)
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.lossRed)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(row.target.name)")
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Brand.self, Category.self, StorageLocation.self, SellingPlatform.self], inMemory: true)
}
