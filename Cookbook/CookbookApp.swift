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
    #if os(macOS)
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    #endif

    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .environmentObject(recipeStore)
                #if os(macOS)
                .preferredColorScheme(appearanceMode.colorScheme)
                #endif
        }
        .commands {
            #if os(macOS)
            CommandGroup(replacing: .newItem) {
                Button("New Recipe") {
                    // This would need to be handled via a published property in RecipeStore
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            #endif
        }

        #if os(macOS)
        Settings {
            AppPreferencesView()
        }
        #endif
    }
}

#if os(macOS)
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum RecipeViewMode: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

struct AppPreferencesView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some View {
        TabView {
            Form {
                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Choose how the app should appear.")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .frame(width: 450)
        }
        .padding(20)
    }
}
#endif
