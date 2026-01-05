import Foundation

/// A complete cookbook export containing metadata, recipes, and categories
struct CookbookExport: Codable {
    let cookbook: Cookbook
    let recipes: [Recipe]
    let categories: [Category]
    let exportDate: Date
    let version: String

    init(cookbook: Cookbook, recipes: [Recipe], categories: [Category]) {
        self.cookbook = cookbook
        self.recipes = recipes
        self.categories = categories
        self.exportDate = Date()
        self.version = "1.0"
    }
}
