//
//  AddItemSheet.swift
//  Fliptrack
//
//  Created by Codex on 6/12/26.
//

import SwiftData
import SwiftUI
import PhotosUI
import UIKit

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Brand.name) private var brands: [Brand]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \StorageLocation.sortOrder) private var storageLocations: [StorageLocation]
    @Query(sort: \SellingPlatform.sortOrder) private var sellingPlatforms: [SellingPlatform]

    @State private var brand = ""
    @State private var category = ""
    @State private var itemDescription = ""
    @State private var purchasePrice = ""
    @State private var storageLocation = ""
    @State private var status: ItemStatus = .unlisted
    @State private var listingPrice = ""
    @State private var selectedPlatforms: Set<String> = []
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var isShowingPhotoOptions = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotoField(photoData: photoData) {
                        isShowingPhotoOptions = true
                    }

                    HStack {
                        Text("Item Number")
                        Spacer()
                        Text(ItemNumberGenerator.previewNextItemNumber())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .listRowBackground(Color.white)

                Section("Item") {
                    BrandAutocompleteField(brand: $brand, options: brandOptions)

                    Picker("Category", selection: $category) {
                        Text("Select").tag("")
                        ForEach(categoryOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                        TextField("", text: $itemDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .textInputAutocapitalization(.sentences)
                    }

                    CurrencyTextField(label: "Purchase Price", text: $purchasePrice)
                }
                .listRowBackground(Color.white)

                Section("Storage") {
                    Picker("Location", selection: $storageLocation) {
                        Text("Select").tag("")
                        ForEach(storageLocationOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
                .listRowBackground(Color.white)

                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Unlisted").tag(ItemStatus.unlisted)
                        Text("Listed").tag(ItemStatus.listed)
                    }
                    .pickerStyle(.segmented)

                    if status == .listed {
                        CurrencyTextField(label: "Listing Price", text: $listingPrice)

                        Text("Listing date is set automatically when you save as Listed")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.white)

                if status == .listed {
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
                }

                Section("Notes") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                        TextField("Optional", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .listRowBackground(Color.white)
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
                    selectedPlatforms = []
                }
            }
            .photoPickerActionSheet(photoData: $photoData, isPresented: $isShowingPhotoOptions)
        }
        .presentationDetents([.large])
    }

    private var categoryOptions: [String] {
        let seeded = categories.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        return seeded.isEmpty ? SeedData.defaultCategories : seeded
    }

    private var brandOptions: [String] {
        brands.map(\.name)
    }

    private var storageLocationOptions: [String] {
        let seeded = storageLocations.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        return seeded.isEmpty ? SeedData.defaultStorageLocations : seeded
    }

    private var platformOptions: [String] {
        let seeded = sellingPlatforms.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        return seeded.isEmpty ? SeedData.defaultPlatforms : seeded
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
                    selectedPlatforms.isEmpty
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
            listingPlatforms: status == .listed ? Array(selectedPlatforms) : [],
            dateListed: status == .listed ? now : nil,
            dateCreated: now,
            photoData: photoData,
            notes: notes.trimmed.nilIfEmpty
        )

        modelContext.insert(item)
        modelContext.insertBrandIfNeeded(brand, existingBrandNames: brands.map(\.name))

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

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Brand.name) private var brands: [Brand]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \StorageLocation.sortOrder) private var storageLocations: [StorageLocation]
    @Query(sort: \SellingPlatform.sortOrder) private var sellingPlatforms: [SellingPlatform]

    let item: Item

    @State private var brand = ""
    @State private var category = ""
    @State private var itemDescription = ""
    @State private var purchasePrice = ""
    @State private var storageLocation = ""
    @State private var status: ItemStatus = .unlisted
    @State private var listingPrice = ""
    @State private var selectedPlatforms: Set<String> = []
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var isShowingPhotoOptions = false
    @State private var isShowingFullPhoto = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotoField(photoData: photoData, action: {
                        isShowingPhotoOptions = true
                    }, viewAction: photoData != nil ? {
                        isShowingFullPhoto = true
                    } : nil)

                    HStack {
                        Text("Item Number")
                        Spacer()
                        Text(item.itemNumber)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .listRowBackground(Color.white)

                Section("Item") {
                    BrandAutocompleteField(brand: $brand, options: brandOptions)

                    Picker("Category", selection: $category) {
                        Text("Select").tag("")
                        ForEach(categoryOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                        TextField("", text: $itemDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .textInputAutocapitalization(.sentences)
                    }

                    CurrencyTextField(label: "Purchase Price", text: $purchasePrice)
                }
                .listRowBackground(Color.white)

                Section("Storage") {
                    Picker("Location", selection: $storageLocation) {
                        Text("Select").tag("")
                        ForEach(storageLocationOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
                .listRowBackground(Color.white)

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ItemStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    if status == .listed || status == .sold {
                        CurrencyTextField(label: "Listing Price", text: $listingPrice)
                    }

                    if status == .sold {
                        LabeledContent("Listed On", value: item.listingPlatforms.joined(separator: ", ").nilIfEmpty ?? "---")
                        LabeledContent("Sold On", value: item.soldPlatformName ?? "---")
                        LabeledContent("Sale Price", value: CurrencyFormatter.string(from: item.salePrice))
                        LabeledContent("Platform Fee", value: CurrencyFormatter.string(from: item.platformFee))
                        LabeledContent("Net Profit", value: CurrencyFormatter.signedString(from: item.profit))
                    }
                }
                .listRowBackground(Color.white)

                if status == .listed {
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
                }

                Section("Notes") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                        TextField("Optional", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .listRowBackground(Color.white)
            }
            .scrollContentBackground(.hidden)
            .background(Color.butterYellow)
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveChanges)
                        .disabled(isSaveDisabled)
                }
            }
            .onAppear(perform: loadItem)
            .onChange(of: status) { _, newStatus in
                if newStatus == .unlisted {
                    listingPrice = ""
                    selectedPlatforms = []
                }
            }
            .photoPickerActionSheet(photoData: $photoData, isPresented: $isShowingPhotoOptions)
            .fullScreenCover(isPresented: $isShowingFullPhoto) {
                if let data = photoData, let image = UIImage(data: data) {
                    FullScreenPhotoView(image: image, onEdit: {
                        isShowingPhotoOptions = true
                    })
                }
            }
        }
        .presentationDetents([.large])
    }

    private var categoryOptions: [String] {
        let seeded = categories.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        let options = seeded.isEmpty ? SeedData.defaultCategories : seeded
        return mergedOptions(options, currentValue: category)
    }

    private var brandOptions: [String] {
        mergedOptions(brands.map(\.name), currentValue: brand)
    }

    private var storageLocationOptions: [String] {
        let seeded = storageLocations.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        let options = seeded.isEmpty ? SeedData.defaultStorageLocations : seeded
        return mergedOptions(options, currentValue: storageLocation)
    }

    private var platformOptions: [String] {
        let seeded = sellingPlatforms.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        let base = seeded.isEmpty ? SeedData.defaultPlatforms : seeded
        let extras = selectedPlatforms.filter { base.contains($0) == false }.sorted()
        return extras + base
    }

    private var isSaveDisabled: Bool {
        itemDescription.trimmed.isEmpty ||
            category.isEmpty ||
            storageLocation.isEmpty ||
            decimal(from: purchasePrice) == nil ||
            decimal(from: purchasePrice).map { $0 <= 0 } == true ||
            ((status == .listed) && (
                    decimal(from: listingPrice) == nil ||
                    decimal(from: listingPrice).map { $0 <= 0 } == true ||
                    selectedPlatforms.isEmpty
            ))
    }

    private func loadItem() {
        brand = item.brand ?? ""
        category = item.category
        itemDescription = item.itemDescription
        purchasePrice = CurrencyFormatter.string(from: item.purchasePrice)
        storageLocation = item.storageLocation
        status = item.status
        if let existingListingPrice = item.listingPrice {
            listingPrice = CurrencyFormatter.string(from: existingListingPrice)
        } else {
            listingPrice = ""
        }
        selectedPlatforms = Set(item.listingPlatforms)
        notes = item.notes ?? ""
        photoData = item.photoData
    }

    private func saveChanges() {
        guard let purchasePrice = decimal(from: purchasePrice) else { return }

        item.brand = brand.trimmed.nilIfEmpty
        item.category = category
        item.itemDescription = itemDescription.trimmed
        item.purchasePrice = purchasePrice
        item.storageLocation = storageLocation
        item.status = status
        item.listingPrice = status == .listed || status == .sold ? decimal(from: listingPrice) : nil
        item.listingPlatforms = status == .listed || status == .sold ? Array(selectedPlatforms) : []
        if status != .sold {
            item.salePrice = nil
            item.platformFee = nil
            item.profit = nil
            item.dateSold = nil
            item.soldPlatformRaw = nil
        }
        if status == .unlisted {
            item.dateListed = nil
        }
        item.photoData = photoData
        item.notes = notes.trimmed.nilIfEmpty
        modelContext.insertBrandIfNeeded(brand, existingBrandNames: brands.map(\.name))

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Could not save item changes: \(error)")
        }
    }

    private func mergedOptions(_ options: [String], currentValue: String) -> [String] {
        guard currentValue.isEmpty == false, options.contains(currentValue) == false else {
            return options
        }

        return [currentValue] + options
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

struct CurrencyTextField: View {
    let label: String
    @Binding var text: String
    var color: Color = Color.primaryText
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in
                    if isFocused == false { formatAsCurrency() }
                }
        }
        .foregroundStyle(color)
    }

    private func formatAsCurrency() {
        let sanitized = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard sanitized.isEmpty == false,
              let val = Decimal(string: sanitized, locale: .current) ?? Decimal(string: sanitized) else {
            return
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        text = formatter.string(from: val as NSDecimalNumber) ?? text
    }
}

private extension ModelContext {
    func insertBrandIfNeeded(_ name: String, existingBrandNames: [String]) {
        let trimmedName = name.trimmed
        guard trimmedName.isEmpty == false else { return }

        let alreadyExists = existingBrandNames.contains {
            $0.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        if alreadyExists == false {
            insert(Brand(name: trimmedName))
        }
    }
}

private extension View {
    func photoPickerActionSheet(photoData: Binding<Data?>, isPresented: Binding<Bool>) -> some View {
        modifier(PhotoPickerActionSheet(photoData: photoData, isPresented: isPresented))
    }
}

private struct BrandAutocompleteField: View {
    @Binding var brand: String
    let options: [String]

    private var suggestions: [String] {
        let query = brand.trimmed
        guard query.isEmpty == false else { return [] }

        let uniqueOptions = Array(Set(options)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if uniqueOptions.contains(where: { $0.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return []
        }

        return uniqueOptions
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .sorted { lhs, rhs in
                let lhsStarts = lhs.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])?.lowerBound == lhs.startIndex
                let rhsStarts = rhs.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])?.lowerBound == rhs.startIndex

                if lhsStarts != rhsStarts {
                    return lhsStarts
                }

                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Brand")
                    .foregroundStyle(Color.primaryText)
                Spacer()
                TextField("Optional", text: $brand)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }

            if suggestions.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                brand = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.softPink.opacity(0.48), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use brand \(suggestion)")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }
}

private struct PhotoPickerActionSheet: ViewModifier {
    @Binding var photoData: Data?
    @Binding var isPresented: Bool
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Item Photo", isPresented: $isPresented, titleVisibility: .visible) {
                Button("Take Photo") {
                    isShowingCamera = true
                }

                Button("Choose from Library") {
                    isShowingPhotoLibrary = true
                }

                if photoData != nil {
                    Button("Remove Photo", role: .destructive) {
                        photoData = nil
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $isShowingPhotoLibrary) {
                PhotoPicker { image in
                    photoData = ImageResizer.jpegData(from: image)
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    photoData = ImageResizer.jpegData(from: image)
                }
            }
    }
}

private struct PhotoField: View {
    let photoData: Data?
    let action: () -> Void
    var viewAction: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main tap: view full-screen if photo exists and viewAction provided, else open picker
            Button(action: image != nil ? (viewAction ?? action) : action) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.55))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                                    .foregroundStyle(Color.hotPink.opacity(0.75))
                            }
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Color.hotPink)
                            }
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photoData == nil ? "Add item photo" : "View item photo")

            // Camera overlay always opens the edit action sheet
            if image != nil {
                Button(action: action) {
                    Image(systemName: "camera.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.hotPink, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: 6)
                .accessibilityLabel("Change item photo")
            }
        }
    }

    private var image: UIImage? {
        guard let photoData else { return nil }
        return UIImage(data: photoData)
    }
}

struct FullScreenPhotoView: View {
    let image: UIImage
    let onEdit: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close photo")

                    Spacer()

                    if let onEdit {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onEdit()
                            }
                        } label: {
                            Label("Edit Photo", systemImage: "camera.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.hotPink, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit photo")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()
            }
        }
    }
}

private struct PhotoPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }

                Task { @MainActor in
                    self.onImagePicked(image)
                }
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

enum ImageResizer {
    static func jpegData(from image: UIImage, maxLongEdge: CGFloat = 1200, compressionQuality: CGFloat = 0.75) -> Data? {
        let orientedImage = image.normalizedOrientation()
        let size = orientedImage.size
        let longestEdge = max(size.width, size.height)

        guard longestEdge > maxLongEdge else {
            return orientedImage.jpegData(compressionQuality: compressionQuality)
        }

        let scale = maxLongEdge / longestEdge
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            orientedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
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
