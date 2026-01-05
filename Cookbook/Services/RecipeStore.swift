import Foundation
import Combine

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var categories: [Category] = []

    private let fileManager = FileManager.default
    private var iCloudURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recipes")
    }

    private var categoriesURL: URL? {
        iCloudURL?.deletingLastPathComponent().appendingPathComponent("categories.json")
    }
    
    init() {
        setupiCloudDirectory()
        loadCategories()
        loadRecipes()

        // Watch for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil
        )
    }
    
    private func setupiCloudDirectory() {
        guard let url = iCloudURL else { return }
        
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    @objc private func iCloudDataChanged() {
        DispatchQueue.main.async {
            self.loadCategories()
            self.loadRecipes()
        }
    }
    
    func loadRecipes() {
        guard let url = iCloudURL else {
            print("iCloud not available")
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "json" }
            
            var loadedRecipes: [Recipe] = []
            
            for fileURL in fileURLs {
                let data = try Data(contentsOf: fileURL)
                let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                loadedRecipes.append(recipe)
            }
            
            DispatchQueue.main.async {
                self.recipes = loadedRecipes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                self.cleanupOrphanedCategoryReferences()
            }
        } catch {
            print("Error loading recipes: \(error)")
        }
    }
    
    func saveRecipe(_ recipe: Recipe) {
        guard let url = iCloudURL else { return }
        
        let fileURL = url.appendingPathComponent("\(recipe.id.uuidString).json")
        
        do {
            let data = try JSONEncoder().encode(recipe)
            try data.write(to: fileURL, options: .atomic)
            
            // Update local array
            if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
                recipes[index] = recipe
            } else {
                recipes.append(recipe)
            }
            recipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            print("Error saving recipe: \(error)")
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        guard let url = iCloudURL else { return }
        
        let fileURL = url.appendingPathComponent("\(recipe.id.uuidString).json")
        
        do {
            try fileManager.removeItem(at: fileURL)
            recipes.removeAll { $0.id == recipe.id }
        } catch {
            print("Error deleting recipe: \(error)")
        }
    }
    
    func addCookedDate(_ recipe: Recipe) {
        var updatedRecipe = recipe
        updatedRecipe.datesCooked.append(Date())
        saveRecipe(updatedRecipe)
    }

    // MARK: - Category Management

    func loadCategories() {
        guard let url = categoriesURL else { return }

        guard fileManager.fileExists(atPath: url.path) else {
            categories = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let loadedCategories = try JSONDecoder().decode([Category].self, from: data)
            DispatchQueue.main.async {
                self.categories = loadedCategories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        } catch {
            print("Error loading categories: \(error)")
            categories = []
        }
    }

    func saveCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
        categories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveCategories()
    }

    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }

        // Remove category from all recipes
        for recipe in recipes where recipe.categoryID == category.id {
            var updatedRecipe = recipe
            updatedRecipe.categoryID = nil
            saveRecipe(updatedRecipe)
        }

        saveCategories()
    }

    private func saveCategories() {
        guard let url = categoriesURL else { return }

        do {
            let data = try JSONEncoder().encode(categories)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Error saving categories: \(error)")
        }
    }

    func category(for recipe: Recipe) -> Category? {
        guard let categoryID = recipe.categoryID else { return nil }
        return categories.first { $0.id == categoryID }
    }

    private func cleanupOrphanedCategoryReferences() {
        let categoryIDs = Set(categories.map { $0.id })

        for recipe in recipes {
            if let categoryID = recipe.categoryID, !categoryIDs.contains(categoryID) {
                // Recipe has a reference to a deleted category, clean it up
                var updatedRecipe = recipe
                updatedRecipe.categoryID = nil
                saveRecipe(updatedRecipe)
            }
        }
    }
}
