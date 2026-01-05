import Foundation
import Combine

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var categories: [Category] = []
    @Published var cookbook: Cookbook
    @Published var availableCookbooks: [Cookbook] = []

    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let currentCookbookKey = "currentCookbookID"

    private var baseURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Cookbooks")
    }

    private var currentCookbookURL: URL? {
        guard let baseURL = baseURL else { return nil }
        return baseURL.appendingPathComponent(cookbook.id.uuidString)
    }

    private var iCloudURL: URL? {
        currentCookbookURL?.appendingPathComponent("Recipes")
    }

    private var categoriesURL: URL? {
        currentCookbookURL?.appendingPathComponent("categories.json")
    }

    private var cookbookMetadataURL: URL? {
        currentCookbookURL?.appendingPathComponent("cookbook.json")
    }
    
    init() {
        // Initialize with default cookbook
        self.cookbook = Cookbook()

        setupBaseDirectory()
        loadAllCookbooks()
        loadCurrentCookbook()
        setupiCloudDirectory()
        loadCookbook()
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

    private func setupBaseDirectory() {
        guard let url = baseURL else { return }

        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func setupiCloudDirectory() {
        guard let url = iCloudURL else { return }
        
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    @objc private func iCloudDataChanged() {
        DispatchQueue.main.async {
            self.loadCookbook()
            self.loadCategories()
            self.loadRecipes()
        }
    }

    // MARK: - Cookbook Management

    func loadAllCookbooks() {
        guard let baseURL = baseURL else { return }

        do {
            let cookbookDirs = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            var cookbooks: [Cookbook] = []
            for dir in cookbookDirs {
                let metadataURL = dir.appendingPathComponent("cookbook.json")
                if fileManager.fileExists(atPath: metadataURL.path),
                   let data = try? Data(contentsOf: metadataURL),
                   let cookbook = try? JSONDecoder().decode(Cookbook.self, from: data) {
                    cookbooks.append(cookbook)
                }
            }

            // Sort and assign synchronously - don't dispatch to main queue yet
            availableCookbooks = cookbooks.sorted { $0.name < $1.name }
        } catch {
            print("Error loading cookbooks: \(error)")
            availableCookbooks = []
        }
    }

    func loadCurrentCookbook() {
        // Try to load the saved current cookbook ID
        if let savedID = userDefaults.string(forKey: currentCookbookKey),
           let uuid = UUID(uuidString: savedID),
           let savedCookbook = availableCookbooks.first(where: { $0.id == uuid }) {
            cookbook = savedCookbook
            print("Loaded saved cookbook: \(savedCookbook.name)")
        } else if let firstCookbook = availableCookbooks.first {
            // Use first available cookbook
            cookbook = firstCookbook
            userDefaults.set(firstCookbook.id.uuidString, forKey: currentCookbookKey)
            print("Loaded first available cookbook: \(firstCookbook.name)")
        } else {
            // Only create default cookbook if no cookbooks exist
            print("No cookbooks found, creating default cookbook")
            cookbook = Cookbook()
            createCookbook(cookbook)
        }
    }

    func loadCookbook() {
        guard let url = cookbookMetadataURL else { return }

        guard fileManager.fileExists(atPath: url.path) else {
            // Create default cookbook if it doesn't exist
            saveCookbook()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let loadedCookbook = try JSONDecoder().decode(Cookbook.self, from: data)
            DispatchQueue.main.async {
                self.cookbook = loadedCookbook
            }
        } catch {
            print("Error loading cookbook: \(error)")
        }
    }

    func saveCookbook() {
        guard let url = cookbookMetadataURL else { return }

        // Ensure directory exists
        if let cookbookDir = currentCookbookURL {
            try? fileManager.createDirectory(at: cookbookDir, withIntermediateDirectories: true)
        }

        var updatedCookbook = cookbook
        updatedCookbook.dateModified = Date()

        do {
            let data = try JSONEncoder().encode(updatedCookbook)
            try data.write(to: url, options: .atomic)
            DispatchQueue.main.async {
                self.cookbook = updatedCookbook
                // Update in available cookbooks
                if let index = self.availableCookbooks.firstIndex(where: { $0.id == updatedCookbook.id }) {
                    self.availableCookbooks[index] = updatedCookbook
                }
            }
        } catch {
            print("Error saving cookbook: \(error)")
        }
    }

    func createCookbook(_ newCookbook: Cookbook) {
        cookbook = newCookbook

        // Create cookbook directory and save metadata
        saveCookbook()
        setupiCloudDirectory()

        // Add to available cookbooks synchronously
        availableCookbooks.append(newCookbook)
        availableCookbooks.sort { $0.name < $1.name }

        // Set as current
        userDefaults.set(newCookbook.id.uuidString, forKey: currentCookbookKey)

        // Reload data for new cookbook
        loadCategories()
        loadRecipes()
    }

    func switchToCookbook(_ targetCookbook: Cookbook) {
        cookbook = targetCookbook
        userDefaults.set(targetCookbook.id.uuidString, forKey: currentCookbookKey)

        // Reload all data for the new cookbook
        loadCookbook()
        loadCategories()
        loadRecipes()
    }

    func deleteCookbook(_ cookbookToDelete: Cookbook) {
        guard let baseURL = baseURL else { return }
        let cookbookDir = baseURL.appendingPathComponent(cookbookToDelete.id.uuidString)

        do {
            try fileManager.removeItem(at: cookbookDir)
            availableCookbooks.removeAll { $0.id == cookbookToDelete.id }

            // If we deleted the current cookbook, switch to another one
            if cookbookToDelete.id == cookbook.id {
                if let firstCookbook = availableCookbooks.first {
                    switchToCookbook(firstCookbook)
                } else {
                    // Create a new default cookbook
                    let newCookbook = Cookbook()
                    createCookbook(newCookbook)
                }
            }
        } catch {
            print("Error deleting cookbook: \(error)")
        }
    }

    // MARK: - Cookbook Import/Export

    func exportCookbook(_ cookbookToExport: Cookbook) -> URL? {
        // Create export data
        let export = CookbookExport(
            cookbook: cookbookToExport,
            recipes: recipes,
            categories: categories
        )

        // Create temporary file
        let tempDir = fileManager.temporaryDirectory
        let fileName = "\(cookbookToExport.name.replacingOccurrences(of: " ", with: "_")).cookbook"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(export)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Error exporting cookbook: \(error)")
            return nil
        }
    }

    func importCookbook(from url: URL) -> Result<Cookbook, Error> {
        do {
            // Ensure we have access to the file
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let export = try decoder.decode(CookbookExport.self, from: data)

            // Create new cookbook with a new ID to avoid conflicts
            var newCookbook = export.cookbook
            newCookbook.id = UUID()
            newCookbook.dateCreated = Date()
            newCookbook.dateModified = Date()

            // Create the cookbook
            createCookbook(newCookbook)

            // Import categories with new IDs, maintaining a mapping
            var categoryIDMapping: [UUID: UUID] = [:]
            for category in export.categories {
                let oldID = category.id
                let newID = UUID()
                categoryIDMapping[oldID] = newID

                var newCategory = category
                newCategory.id = newID
                saveCategory(newCategory)
            }

            // Import recipes with new IDs and updated category references
            for recipe in export.recipes {
                var newRecipe = recipe
                newRecipe.id = UUID()
                newRecipe.dateCreated = Date()

                // Update category reference if it exists
                if let oldCategoryID = recipe.categoryID,
                   let newCategoryID = categoryIDMapping[oldCategoryID] {
                    newRecipe.categoryID = newCategoryID
                } else {
                    newRecipe.categoryID = nil
                }

                // Reset cooking history for imported recipes
                newRecipe.datesCooked = []

                // Reset checked ingredients
                newRecipe.ingredients = newRecipe.ingredients.map { ingredient in
                    var newIngredient = ingredient
                    newIngredient.isChecked = false
                    return newIngredient
                }

                saveRecipe(newRecipe)
            }

            return .success(newCookbook)
        } catch {
            print("Error importing cookbook: \(error)")
            return .failure(error)
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
