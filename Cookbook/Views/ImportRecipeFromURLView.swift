import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImportRecipeFromURLView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    @State private var urlString: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var parsedRecipe: RecipeURLImporter.ParsedRecipe?
    @State private var previewImageData: Data?

    init(initialURL: String = "") {
        _urlString = State(initialValue: initialURL)
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                ScrollView {
                    VStack(spacing: 20) {
                        urlInputSection
                        if let error = errorMessage {
                            errorSection(error)
                        }
                        if let parsed = parsedRecipe {
                            previewSection(parsed)
                            ingredientsPreview(parsed)
                            directionsPreview(parsed)
                            saveSection
                        }
                    }
                    .padding()
                    .frame(minWidth: 500, maxWidth: 700)
                }
                #else
                Form {
                    urlInputSection
                    if let error = errorMessage {
                        errorSection(error)
                    }
                    if let parsed = parsedRecipe {
                        previewSection(parsed)
                        ingredientsPreview(parsed)
                        directionsPreview(parsed)
                        saveSection
                    }
                }
                #endif
            }
            .navigationTitle("Import from URL")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !urlString.isEmpty && parsedRecipe == nil {
                    fetchRecipe()
                }
            }
        }
    }

    // MARK: - Sections

    private var urlInputSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe URL")
                .font(.headline)
            TextField("https://example.com/recipe", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .onSubmit(fetchRecipe)
            Text("Paste a URL from a recipe website to automatically import the ingredients and steps.")
                .font(.caption)
                .foregroundColor(.secondary)
            fetchButton
        }
        #else
        Section {
            TextField("https://example.com/recipe", text: $urlString)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onSubmit(fetchRecipe)
            fetchButton
        } header: {
            Text("Recipe URL")
        } footer: {
            Text("Paste a URL from a recipe website to automatically import the ingredients and steps.")
        }
        #endif
    }

    private var fetchButton: some View {
        Button(action: fetchRecipe) {
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching recipe...")
                }
            } else {
                Label("Fetch Recipe", systemImage: "arrow.down.circle")
            }
        }
        .disabled(urlString.isEmpty || isLoading)
    }

    private func errorSection(_ error: String) -> some View {
        #if os(macOS)
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(error)
                .foregroundColor(.red)
        }
        #else
        Section {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
        #endif
    }

    private func previewSection(_ parsed: RecipeURLImporter.ParsedRecipe) -> some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            if let previewImageData, let nsImage = NSImage(data: previewImageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            LabeledContent("Title", value: parsed.title)
            LabeledContent("Ingredients", value: "\(parsed.ingredients.count)")
            LabeledContent("Steps", value: "\(parsed.directions.count)")
            if parsed.prepDuration > 0 {
                LabeledContent("Prep Time", value: formatDuration(parsed.prepDuration))
            }
            if parsed.cookDuration > 0 {
                LabeledContent("Cook Time", value: formatDuration(parsed.cookDuration))
            }
        }
        #else
        Section("Preview") {
            if let previewImageData, let uiImage = UIImage(data: previewImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .listRowInsets(EdgeInsets())
            }
            LabeledContent("Title", value: parsed.title)
            LabeledContent("Ingredients", value: "\(parsed.ingredients.count)")
            LabeledContent("Steps", value: "\(parsed.directions.count)")
            if parsed.prepDuration > 0 {
                LabeledContent("Prep Time", value: formatDuration(parsed.prepDuration))
            }
            if parsed.cookDuration > 0 {
                LabeledContent("Cook Time", value: formatDuration(parsed.cookDuration))
            }
        }
        #endif
    }

    @ViewBuilder
    private func ingredientsPreview(_ parsed: RecipeURLImporter.ParsedRecipe) -> some View {
        if !parsed.ingredients.isEmpty {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingredients")
                    .font(.headline)
                ForEach(parsed.ingredients, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.subheadline)
                }
            }
            #else
            Section("Ingredients") {
                ForEach(parsed.ingredients, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.subheadline)
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func directionsPreview(_ parsed: RecipeURLImporter.ParsedRecipe) -> some View {
        if !parsed.directions.isEmpty {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
                Text("Directions")
                    .font(.headline)
                ForEach(Array(parsed.directions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            #else
            Section("Directions") {
                ForEach(Array(parsed.directions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            #endif
        }
    }

    private var saveSection: some View {
        #if os(macOS)
        HStack {
            Spacer()
            Button(action: saveRecipe) {
                Label("Save Recipe", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        #else
        Section {
            Button(action: saveRecipe) {
                Label("Save Recipe", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .font(.headline)
        }
        #endif
    }

    // MARK: - Actions

    private func fetchRecipe() {
        guard !urlString.isEmpty else { return }

        // Add https:// if no scheme is present
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }

        isLoading = true
        errorMessage = nil
        parsedRecipe = nil
        previewImageData = nil

        Task {
            do {
                let parsed = try await RecipeURLImporter.importRecipe(from: urlString)
                parsedRecipe = parsed
                isLoading = false

                // Load preview image in background
                if let imageURL = parsed.imageURL {
                    if let imageData = await RecipeURLImporter.downloadImage(from: imageURL) {
                        previewImageData = imageData
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func saveRecipe() {
        guard let parsed = parsedRecipe else { return }

        var recipe = Recipe(
            title: parsed.title,
            ingredients: parsed.ingredients.map { Ingredient(text: $0) },
            directions: parsed.directions.enumerated().map { Direction(text: $1, order: $0 + 1) },
            sourceURL: parsed.sourceURL,
            prepDuration: parsed.prepDuration,
            cookDuration: parsed.cookDuration,
            notes: parsed.notes
        )

        // Use already-downloaded preview image if available, otherwise fetch in background
        if let previewImageData {
            recipe.imageData = previewImageData
        }

        store.saveRecipe(recipe)

        if previewImageData == nil, let imageURL = parsed.imageURL {
            Task.detached {
                if let imageData = await RecipeURLImporter.downloadImage(from: imageURL) {
                    await MainActor.run {
                        recipe.imageData = imageData
                        store.saveRecipe(recipe)
                    }
                }
            }
        }

        dismiss()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
}

#Preview {
    ImportRecipeFromURLView()
        .environmentObject(RecipeStore())
}
