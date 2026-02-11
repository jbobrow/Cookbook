import SwiftUI
import PhotosUI

struct RecipeEditView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    @State var recipe: Recipe
    @State private var isNewRecipe: Bool
    @State private var originalRecipe: Recipe

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var newIngredient = ""
    @State private var newDirection = ""
    @State private var showingDiscardAlert = false

    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
        _isNewRecipe = State(initialValue: recipe.title.isEmpty)
        _originalRecipe = State(initialValue: recipe)
    }

    private var hasUnsavedChanges: Bool {
        // Check if recipe has been modified
        if recipe.title != originalRecipe.title { return true }
        if recipe.sourceURL != originalRecipe.sourceURL { return true }
        if recipe.rating != originalRecipe.rating { return true }
        if recipe.categoryID != originalRecipe.categoryID { return true }
        if recipe.prepDuration != originalRecipe.prepDuration { return true }
        if recipe.cookDuration != originalRecipe.cookDuration { return true }
        if recipe.notes != originalRecipe.notes { return true }
        if recipe.imageData != originalRecipe.imageData { return true }

        // Check ingredients
        if recipe.ingredients.count != originalRecipe.ingredients.count { return true }
        for (index, ingredient) in recipe.ingredients.enumerated() {
            if index >= originalRecipe.ingredients.count { return true }
            if ingredient.text != originalRecipe.ingredients[index].text { return true }
        }

        // Check directions
        if recipe.directions.count != originalRecipe.directions.count { return true }
        for (index, direction) in recipe.directions.enumerated() {
            if index >= originalRecipe.directions.count { return true }
            if direction.text != originalRecipe.directions[index].text { return true }
        }

        return false
    }
    
    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                ScrollView {
                    VStack(spacing: 20) {
                        imageSection
                        basicInfoSection
                        timeSection
                        ingredientsSection
                        directionsSection
                        notesSection
                    }
                    .padding()
                    .frame(minWidth: 500, maxWidth: 700)
                }
                #else
                Form {
                    imageSection
                    basicInfoSection
                    timeSection
                    ingredientsSection
                    directionsSection
                    notesSection
                }
                #endif
            }
            #if os(macOS)
            .navigationTitle(isNewRecipe ? "New Recipe" : "Edit Recipe")
            #else
            .navigationTitle(isNewRecipe ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .disabled(recipe.title.isEmpty)
                }
            }
            #if os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        recipe.imageData = data
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }

    private func handleCancel() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private var imageSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            if let imageData = recipe.imageData,
               let image = createPlatformImage(from: imageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        }
        #else
        Section {
            VStack {
                if let imageData = recipe.imageData,
                   let image = createPlatformImage(from: imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                }
            }
        }
        #endif
    }

    private var basicInfoSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Recipe Title", text: $recipe.title)
                    .textFieldStyle(.roundedBorder)

                TextField("Source URL", text: $recipe.sourceURL)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Rating")
                    Spacer()
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            if recipe.rating == star {
                                recipe.rating = 0
                            } else {
                                recipe.rating = star
                            }
                        }) {
                            Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                                .foregroundColor(star <= recipe.rating ? .yellow : .gray)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                CategoryPicker(selectedCategoryID: $recipe.categoryID)
            }
        }
        #else
        Section("Basic Information") {
            TextField("Recipe Title", text: $recipe.title)

            TextField("Source URL", text: $recipe.sourceURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)

            HStack {
                Text("Rating")
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        if recipe.rating == star {
                            recipe.rating = 0
                        } else {
                            recipe.rating = star
                        }
                    }) {
                        Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                            .foregroundColor(star <= recipe.rating ? .yellow : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }

            CategoryPicker(selectedCategoryID: $recipe.categoryID)
        }
        #endif
    }

    private var timeSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Time")
                .font(.headline)

            VStack(spacing: 8) {
                DurationPicker(title: "Prep Time", duration: $recipe.prepDuration)
                DurationPicker(title: "Cook Time", duration: $recipe.cookDuration)
            }
        }
        #else
        Section("Time") {
            DurationPicker(title: "Prep Time", duration: $recipe.prepDuration)
            DurationPicker(title: "Cook Time", duration: $recipe.cookDuration)
        }
        #endif
    }

    private var ingredientsSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach($recipe.ingredients) { $ingredient in
                    HStack {
                        TextField("Ingredient", text: $ingredient.text)
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            recipe.ingredients.removeAll { $0.id == ingredient.id }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Add ingredient", text: $newIngredient)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addIngredient)
                    Button(action: addIngredient) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(newIngredient.isEmpty)
                }
            }
        }
        #else
        Section("Ingredients") {
            ForEach($recipe.ingredients) { $ingredient in
                HStack {
                    TextField("Ingredient", text: $ingredient.text)
                    Button(action: {
                        recipe.ingredients.removeAll { $0.id == ingredient.id }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("Add ingredient", text: $newIngredient)
                    .onSubmit(addIngredient)
                Button(action: addIngredient) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(newIngredient.isEmpty)
            }
        }
        #endif
    }

    private var directionsSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(recipe.directions.sorted(by: { $0.order < $1.order })) { direction in
                    if let index = recipe.directions.firstIndex(where: { $0.id == direction.id }) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(direction.order).")
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            TextField("Step", text: $recipe.directions[index].text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                            Button(action: {
                                recipe.directions.removeAll { $0.id == direction.id }
                                reorderDirections()
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("\(recipe.directions.count + 1).")
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    TextField("Add step", text: $newDirection, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .onSubmit(addDirection)
                    Button(action: addDirection) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(newDirection.isEmpty)
                }
            }
        }
        #else
        Section("Directions") {
            ForEach(recipe.directions.sorted(by: { $0.order < $1.order })) { direction in
                if let index = recipe.directions.firstIndex(where: { $0.id == direction.id }) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(direction.order).")
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        TextField("Step", text: $recipe.directions[index].text, axis: .vertical)
                            .lineLimit(3...6)
                        Button(action: {
                            recipe.directions.removeAll { $0.id == direction.id }
                            reorderDirections()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Text("\(recipe.directions.count + 1).")
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .trailing)
                TextField("Add step", text: $newDirection, axis: .vertical)
                    .lineLimit(3...6)
                    .onSubmit(addDirection)
                Button(action: addDirection) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(newDirection.isEmpty)
            }
        }
        #endif
    }

    private var notesSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $recipe.notes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        #else
        Section("Notes") {
            TextEditor(text: $recipe.notes)
                .frame(minHeight: 100)
        }
        #endif
    }
    
    private func createPlatformImage(from data: Data) -> Image? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
    
    private func addIngredient() {
        guard !newIngredient.isEmpty else { return }
        recipe.ingredients.append(Ingredient(text: newIngredient))
        newIngredient = ""
    }
    
    private func addDirection() {
        guard !newDirection.isEmpty else { return }
        recipe.directions.append(Direction(text: newDirection, order: recipe.directions.count + 1))
        newDirection = ""
    }
    
    private func reorderDirections() {
        recipe.directions = recipe.directions.enumerated().map { index, direction in
            var updated = direction
            updated.order = index + 1
            return updated
        }
    }
    
    private func saveRecipe() {
        store.saveRecipe(recipe)
        dismiss()
    }
}

struct DurationPicker: View {
    let title: String
    @Binding var duration: TimeInterval
    
    private var hours: Int {
        Int(duration) / 3600
    }
    
    private var minutes: Int {
        (Int(duration) % 3600) / 60
    }
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 8) {
                Picker("Hours", selection: Binding(
                    get: { hours },
                    set: { duration = TimeInterval($0 * 3600 + minutes * 60) }
                )) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)h").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("Minutes", selection: Binding(
                    get: { minutes },
                    set: { duration = TimeInterval(hours * 3600 + $0 * 60) }
                )) {
                    ForEach(0..<60, id: \.self) { minute in
                        if minute % 5 == 0 {
                            Text("\(minute)m").tag(minute)
                        }
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }
}

#Preview {
    RecipeEditView(recipe: Recipe())
        .environmentObject(RecipeStore())
}
