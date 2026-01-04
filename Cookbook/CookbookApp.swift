//
//  CookbookApp.swift
//  Cookbook
//
//  Created by Jonathan Bobrow on 1/4/26.
//

import SwiftUI

@main
struct CookbookApp: App {
    @StateObject private var recipeStore = RecipeStore()
    
    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .environmentObject(recipeStore)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Recipe") {
                    // This would need to be handled via a published property in RecipeStore
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
    }
}
