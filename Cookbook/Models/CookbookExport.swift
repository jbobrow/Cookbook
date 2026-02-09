import Foundation

/// A complete cookbook export containing metadata, recipes, and categories
struct CookbookExport: Codable {
    let cookbook: Cookbook
    let recipes: [Recipe]
    let categories: [Category]
    let images: [String: Data]  // imageName -> imageData for portable export
    let exportDate: Date
    let version: String

    init(cookbook: Cookbook, recipes: [Recipe], categories: [Category], images: [String: Data] = [:]) {
        self.cookbook = cookbook
        self.recipes = recipes
        self.categories = categories
        self.images = images
        self.exportDate = Date()
        self.version = "1.0"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cookbook = try container.decode(Cookbook.self, forKey: .cookbook)
        recipes = try container.decode([Recipe].self, forKey: .recipes)
        categories = try container.decode([Category].self, forKey: .categories)
        images = try container.decodeIfPresent([String: Data].self, forKey: .images) ?? [:]
        exportDate = try container.decode(Date.self, forKey: .exportDate)
        version = try container.decode(String.self, forKey: .version)
    }
}
