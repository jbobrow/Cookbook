import Foundation
import SwiftUI

struct Cookbook: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date

    init(id: UUID = UUID(), name: String = "My Cookbook", dateCreated: Date = Date(), dateModified: Date = Date()) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
}
