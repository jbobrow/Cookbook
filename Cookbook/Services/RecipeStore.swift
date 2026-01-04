import Foundation
import Combine

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    
    private let fileManager = FileManager.default
    private var iCloudURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recipes")
    }
    
    init() {
        setupiCloudDirectory()
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
}
