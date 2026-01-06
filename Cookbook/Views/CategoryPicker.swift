import SwiftUI

struct CategoryPicker: View {
    @EnvironmentObject var store: RecipeStore
    @Binding var selectedCategoryID: UUID?
    @State private var showingCategoryEditor = false
    @State private var editingCategory: Category?
    @State private var categoryToDelete: Category?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack {
            #if os(macOS)
            HStack {
                Text("Category")
                    .foregroundColor(.primary)
                Spacer()
                Picker("", selection: $selectedCategoryID) {
                    Text("None").tag(nil as UUID?)

                    Divider()

                    ForEach(store.categories) { category in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            Text(category.name)
                        }
                        .tag(category.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            #else
            Menu {
                Button(action: { selectedCategoryID = nil }) {
                    Label("None", systemImage: selectedCategoryID == nil ? "checkmark" : "")
                }

                Divider()

                ForEach(store.categories) { category in
                    Button(action: { selectedCategoryID = category.id }) {
                        Label(category.name, systemImage: selectedCategoryID == category.id ? "checkmark" : "")
                    }
                }

                Divider()

                Button(action: { createNewCategory() }) {
                    Label("New Category", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text("Category")
                        .foregroundColor(.secondary)
                    Spacer()
                    if let selectedID = selectedCategoryID,
                       let category = store.categories.first(where: { $0.id == selectedID }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            Text(category.name)
                                .foregroundColor(.primary)
                        }
                    } else {
                        Text("None")
                            .foregroundColor(.primary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            #endif

            Menu {
                Button(action: { createNewCategory() }) {
                    Label("New Category", systemImage: "plus")
                }

                if let selectedID = selectedCategoryID,
                   let category = store.categories.first(where: { $0.id == selectedID }) {
                    Divider()
                    Button(action: { editCategory(category) }) {
                        Label("Edit '\(category.name)'", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { confirmDeleteCategory(category) }) {
                        Label("Delete '\(category.name)'", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorView(category: category, selectedCategoryID: $selectedCategoryID)
        }
        .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive, action: deleteCategory)
        } message: {
            if let category = categoryToDelete {
                let recipeCount = store.recipes.filter { $0.categoryID == category.id }.count
                if recipeCount > 0 {
                    Text("Are you sure you want to delete '\(category.name)'? This will remove the category from \(recipeCount) recipe\(recipeCount == 1 ? "" : "s").")
                } else {
                    Text("Are you sure you want to delete '\(category.name)'?")
                }
            }
        }
    }

    private func createNewCategory() {
        editingCategory = Category(name: "", colorHex: "#289CFF")
    }

    private func editCategory(_ category: Category) {
        editingCategory = category
    }

    private func confirmDeleteCategory(_ category: Category) {
        categoryToDelete = category
        showingDeleteConfirmation = true
    }

    private func deleteCategory() {
        guard let category = categoryToDelete else { return }
        store.deleteCategory(category)
        if selectedCategoryID == category.id {
            selectedCategoryID = nil
        }
        categoryToDelete = nil
    }
}

struct CategoryChipWrapper: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Text(category.name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : category.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? category.color : category.color.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(category.color, lineWidth: isSelected ? 0 : 1)
                )
                .onTapGesture {
                    onSelect()
                }
                .contextMenu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .fixedSize()
    }
}

struct CategoryEditorView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategoryID: UUID?
    @State private var category: Category
    @State private var name: String
    @State private var selectedColor: Color

    private let colorOptions: [Color] = [
        Color(hex: "#FF5040"), // Red
        Color(hex: "#FF9450"), // Orange
        Color(hex: "#FFCD35"), // Yellow
        Color(hex: "#9AD63A"), // Green
        Color(hex: "#35CCBE"), // Teal
        Color(hex: "#289CFF"), // Blue
        Color(hex: "#9179FF"), // Purple
        Color(hex: "#F355A6"), // Pink
        Color(hex: "#787B7F"), // Dark Gray
        Color(hex: "#D9D9D9"), // Light Gray
    ]

    init(category: Category, selectedCategoryID: Binding<UUID?>) {
        _category = State(initialValue: category)
        _name = State(initialValue: category.name)
        _selectedColor = State(initialValue: category.color)
        _selectedCategoryID = selectedCategoryID
    }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Category Name")
                    .font(.headline)
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                    ForEach(colorOptions, id: \.self) { color in
                        Button(action: { selectedColor = color }) {
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: selectedColor.toHex() == color.toHex() ? 3 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveCategory()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        #else
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("Name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(colorOptions, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: selectedColor.toHex() == color.toHex() ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(category.name.isEmpty ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #endif
    }

    private func saveCategory() {
        var updatedCategory = category
        updatedCategory.name = name.trimmingCharacters(in: .whitespaces)
        updatedCategory.colorHex = selectedColor.toHex()

        let isNewCategory = category.name.isEmpty
        store.saveCategory(updatedCategory)

        // Auto-select newly created categories
        if isNewCategory {
            selectedCategoryID = updatedCategory.id
        }

        dismiss()
    }
}

#Preview {
    CategoryPicker(selectedCategoryID: .constant(nil))
        .environmentObject(RecipeStore())
        .padding()
}
