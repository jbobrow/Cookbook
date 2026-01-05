import SwiftUI
import PhotosUI

struct RecipeEditView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    @State var recipe: Recipe
    @State private var isNewRecipe: Bool
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var newIngredient = ""
    @State private var newDirection = ""
    
    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
        _isNewRecipe = State(initialValue: recipe.title.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                imageSection
                basicInfoSection
                timeSection
                ingredientsSection
                directionsSection
                notesSection
            }
            .navigationTitle(isNewRecipe ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .disabled(recipe.title.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        recipe.imageData = data
                    }
                }
            }
        }
    }

    private var imageSection: some View {
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
    }

    private var basicInfoSection: some View {
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
    }

    private var timeSection: some View {
        Section("Time") {
            DurationPicker(title: "Prep Time", duration: $recipe.prepDuration)
            DurationPicker(title: "Cook Time", duration: $recipe.cookDuration)
        }
    }

    private var ingredientsSection: some View {
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
                }
            }

            HStack {
                TextField("Add ingredient", text: $newIngredient)
                    .onSubmit(addIngredient)
                Button(action: addIngredient) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .disabled(newIngredient.isEmpty)
            }
        }
    }

    private var directionsSection: some View {
        Section("Directions") {
            ForEach(recipe.directions.sorted(by: { $0.order < $1.order })) { direction in
                if let index = recipe.directions.firstIndex(where: { $0.id == direction.id }) {
                    HStack(alignment: .top) {
                        Text("\(direction.order + 1).")
                            .foregroundColor(.secondary)
                        TextField("Step", text: $recipe.directions[index].text, axis: .vertical)
                            .lineLimit(3...6)
                        Button(action: {
                            recipe.directions.removeAll { $0.id == direction.id }
                            reorderDirections()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            HStack(alignment: .top) {
                Text("\(recipe.directions.count + 1).")
                    .foregroundColor(.secondary)
                TextField("Add step", text: $newDirection, axis: .vertical)
                    .lineLimit(3...6)
                    .onSubmit(addDirection)
                Button(action: addDirection) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .disabled(newDirection.isEmpty)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $recipe.notes)
                .frame(minHeight: 100)
        }
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
        recipe.directions.append(Direction(text: newDirection, order: recipe.directions.count))
        newDirection = ""
    }
    
    private func reorderDirections() {
        recipe.directions = recipe.directions.enumerated().map { index, direction in
            var updated = direction
            updated.order = index
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
            Picker("Hours", selection: Binding(
                get: { hours },
                set: { duration = TimeInterval($0 * 3600 + minutes * 60) }
            )) {
                ForEach(0..<24) { hour in
                    Text("\(hour)h").tag(hour)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
            
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
            .frame(width: 70)
        }
    }
}

#Preview {
    RecipeEditView(recipe: Recipe())
        .environmentObject(RecipeStore())
}
