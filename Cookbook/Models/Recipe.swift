import Foundation
import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

struct Recipe: Identifiable, Codable {
    var id: UUID
    var title: String
    var imageData: Data?
    var ingredients: [Ingredient]
    var directions: [Direction]
    var dateCreated: Date
    var datesCooked: [Date]
    var sourceURL: String
    var rating: Int // 0-5 stars
    var prepDuration: TimeInterval // in seconds
    var cookDuration: TimeInterval // in seconds
    var notes: String
    var categoryID: UUID?
    
    init(
        id: UUID = UUID(),
        title: String = "",
        imageData: Data? = nil,
        ingredients: [Ingredient] = [],
        directions: [Direction] = [],
        dateCreated: Date = Date(),
        datesCooked: [Date] = [],
        sourceURL: String = "",
        rating: Int = 0,
        prepDuration: TimeInterval = 0,
        cookDuration: TimeInterval = 0,
        notes: String = "",
        categoryID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.imageData = imageData
        self.ingredients = ingredients
        self.directions = directions
        self.dateCreated = dateCreated
        self.datesCooked = datesCooked
        self.sourceURL = sourceURL
        self.rating = rating
        self.prepDuration = prepDuration
        self.cookDuration = cookDuration
        self.notes = notes
        self.categoryID = categoryID
    }
    
    var image: Image? {
        guard let imageData = imageData else { return nil }
        
        #if os(iOS)
        guard let uiImage = UIImage(data: imageData) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: imageData) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
}

struct Ingredient: Identifiable, Codable {
    var id: UUID
    var text: String
    var isChecked: Bool
    
    init(id: UUID = UUID(), text: String, isChecked: Bool = false) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
    }
}

struct Direction: Identifiable, Codable {
    var id: UUID
    var text: String
    var order: Int
    
    init(id: UUID = UUID(), text: String, order: Int) {
        self.id = id
        self.text = text
        self.order = order
    }
}
