import SwiftUI
import UniformTypeIdentifiers

struct RecipeListView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var searchText = ""
    @State private var showingAddRecipe = false
    @State private var showingImportSheet = false
    @State private var showingImportCookbookSheet = false
    @State private var showingSettings = false
    @State private var showingCookbookSwitcher = false
    @State private var importAlert: ImportAlert?
    @State private var recipesToDelete: IndexSet?
    @State private var showingDeleteConfirmation = false
    
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return store.recipes
        }
        return store.recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var groupedRecipes: [(category: Category?, recipes: [Recipe])] {
        if store.categories.isEmpty {
            return [(nil, filteredRecipes)]
        }

        var groups: [(Category?, [Recipe])] = []
        let categoryIDs = Set(store.categories.map { $0.id })

        // Group recipes by category
        for category in store.categories {
            let categoryRecipes = filteredRecipes.filter { $0.categoryID == category.id }
            if !categoryRecipes.isEmpty {
                groups.append((category, categoryRecipes))
            }
        }

        // Add uncategorized recipes (recipes with no category OR orphaned category references)
        let uncategorized = filteredRecipes.filter { recipe in
            recipe.categoryID == nil || !categoryIDs.contains(recipe.categoryID!)
        }
        if !uncategorized.isEmpty {
            groups.append((nil, uncategorized))
        }

        return groups
    }
    
    private var recipeList: some View {
        List {
            ForEach(Array(groupedRecipes.enumerated()), id: \.offset) { groupIndex, group in
                Section {
                    ForEach(group.recipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRowView(recipe: recipe, showCategory: false)
                        }
                        .swipeActions(edge: .leading) {
                            Button(action: { shareRecipe(recipe) }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        deleteRecipesInSection(at: offsets, in: groupIndex)
                    }
                } header: {
                    if let category = group.category {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            Text(category.name)
                        }
                    } else if !store.categories.isEmpty {
                        Text("Uncategorized")
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            recipeList
            #if os(iOS)
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle(store.cookbook.name)
            .navigationBarTitleDisplayMode(.inline)
            #else
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search recipes")
            .navigationTitle("")
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingCookbookSwitcher = true }) {
                        Image(systemName: "books.vertical")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    CookbookTitleView(cookbookName: store.cookbook.name, showingSettings: $showingSettings)
                        .padding(.trailing, 8)
                }
                #else
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingCookbookSwitcher = true }) {
                        Image(systemName: "books.vertical")
                    }
                }
                #endif

                #if !os(macOS)
                ToolbarItem(placement: .principal) {
                    Button(action: { showingSettings = true }) {
                        Text(store.cookbook.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                #endif

                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(action: { showingAddRecipe = true }) {
                            Label("New Recipe", systemImage: "plus")
                        }
                        Button(action: { showingImportSheet = true }) {
                            Label("Import Recipe", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(action: { showingImportCookbookSheet = true }) {
                            Label("Import Cookbook", systemImage: "book.closed")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                RecipeEditView(recipe: Recipe())
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingCookbookSwitcher) {
                CookbookSwitcherView()
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json, UTType(filenameExtension: "cookbook.json") ?? .json],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result: result)
            }
            .fileImporter(
                isPresented: $showingImportCookbookSheet,
                allowedContentTypes: [UTType(filenameExtension: "cookbook") ?? .json],
                allowsMultipleSelection: false
            ) { result in
                handleCookbookImport(result: result)
            }
            .alert(item: $importAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Delete Recipe\(deleteCount > 1 ? "s" : "")", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    recipesToDelete = nil
                }
                Button("Delete", role: .destructive, action: confirmDelete)
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var deleteCount: Int {
        recipesToDelete?.count ?? 0
    }

    private var deleteMessage: String {
        guard let offsets = recipesToDelete else { return "" }

        if offsets.count == 1, let index = offsets.first {
            let recipe = filteredRecipes[index]
            return "Are you sure you want to delete '\(recipe.title)'? This action cannot be undone."
        } else {
            return "Are you sure you want to delete \(offsets.count) recipes? This action cannot be undone."
        }
    }
    
    private func deleteRecipesInSection(at offsets: IndexSet, in sectionIndex: Int) {
        let group = groupedRecipes[sectionIndex]
        let recipesToDeleteList = offsets.map { group.recipes[$0] }

        // Show confirmation with recipe names
        recipesToDelete = IndexSet(recipesToDeleteList.compactMap { recipe in
            filteredRecipes.firstIndex(where: { $0.id == recipe.id })
        })
        showingDeleteConfirmation = true
    }

    private func deleteRecipes(at offsets: IndexSet) {
        recipesToDelete = offsets
        showingDeleteConfirmation = true
    }

    private func confirmDelete() {
        guard let offsets = recipesToDelete else { return }

        offsets.forEach { index in
            let recipe = filteredRecipes[index]
            store.deleteRecipe(recipe)
        }

        recipesToDelete = nil
    }
    
    private func shareRecipe(_ recipe: Recipe) {
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(recipe.title.replacingOccurrences(of: " ", with: "_")).cookbook.json"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recipe)
            try data.write(to: fileURL)
            
            // Present share sheet
            #if os(iOS)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            #elseif os(macOS)
            let picker = NSSharingServicePicker(items: [fileURL])
            if let view = NSApplication.shared.keyWindow?.contentView {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
            #endif
        } catch {
            print("Error sharing recipe: \(error)")
        }
    }
    
    private func handleCookbookImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let importResult = store.importCookbook(from: url)

            switch importResult {
            case .success(let cookbook):
                importAlert = ImportAlert(
                    title: "Import Successful",
                    message: "Successfully imported '\(cookbook.name)' with all its recipes and categories!"
                )
            case .failure(let error):
                importAlert = ImportAlert(
                    title: "Import Failed",
                    message: "Could not import cookbook: \(error.localizedDescription)"
                )
            }

        case .failure(let error):
            print("Error selecting file: \(error)")
            importAlert = ImportAlert(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var successCount = 0
            var errorCount = 0
            
            for url in urls {
                do {
                    // Ensure we have access to the file
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    let data = try Data(contentsOf: url)
                    var recipe = try JSONDecoder().decode(Recipe.self, from: data)
                    
                    // Generate new ID to avoid conflicts
                    recipe.id = UUID()
                    recipe.dateCreated = Date()
                    
                    // Reset checked ingredients for fresh cooking
                    recipe.ingredients = recipe.ingredients.map { ingredient in
                        var newIngredient = ingredient
                        newIngredient.isChecked = false
                        return newIngredient
                    }
                    
                    store.saveRecipe(recipe)
                    successCount += 1
                } catch {
                    print("Error importing recipe from \(url.lastPathComponent): \(error)")
                    errorCount += 1
                }
            }
            
            // Show result
            if successCount > 0 {
                let message = errorCount > 0
                    ? "Imported \(successCount) recipe\(successCount == 1 ? "" : "s"). Failed to import \(errorCount)."
                    : "Successfully imported \(successCount) recipe\(successCount == 1 ? "" : "s")!"
                
                importAlert = ImportAlert(
                    title: "Import Complete",
                    message: message
                )
            } else if errorCount > 0 {
                importAlert = ImportAlert(
                    title: "Import Failed",
                    message: "Could not import any recipes. Please check the file format."
                )
            }
            
        case .failure(let error):
            print("Error selecting files: \(error)")
            importAlert = ImportAlert(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }
}

struct RecipeRowView: View {
    let recipe: Recipe
    var showCategory: Bool = true
    @EnvironmentObject var store: RecipeStore

    var body: some View {
        HStack(spacing: 12) {
            // Recipe image thumbnail
            if let imageData = recipe.imageData,
               let image = createPlatformImage(from: imageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if showCategory, let category = store.category(for: recipe) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if recipe.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<recipe.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }

                    if recipe.prepDuration > 0 || recipe.cookDuration > 0 {
                        Text(formatTotalTime(prep: recipe.prepDuration, cook: recipe.cookDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !recipe.datesCooked.isEmpty {
                    Text("Cooked \(recipe.datesCooked.count) time\(recipe.datesCooked.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
    
    private func formatTotalTime(prep: TimeInterval, cook: TimeInterval) -> String {
        let total = Int((prep + cook) / 60)
        if total < 60 {
            return "\(total) min"
        } else {
            let hours = total / 60
            let minutes = total % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}

// Helper struct for import alerts
struct ImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#if os(macOS)
struct CookbookTitleView: View {
    let cookbookName: String
    @Binding var showingSettings: Bool
    @State private var isHovered = false

    var body: some View {
        Text(cookbookName)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
            .contentShape(Rectangle())
            .onTapGesture {
                showingSettings = true
            }
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
#endif

#Preview {
    RecipeListView()
        .environmentObject(RecipeStore())
}
