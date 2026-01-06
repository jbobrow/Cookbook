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
    @AppStorage("textSizeMultiplier") private var textSizeMultiplier: Double = 1.0
    #endif

    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .environmentObject(recipeStore)
                #if os(macOS)
                .preferredColorScheme(appearanceMode.colorScheme)
                .environment(\.textSizeMultiplier, textSizeMultiplier)
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

            CommandMenu("View") {
                Button("Increase Text Size") {
                    textSizeMultiplier = min(textSizeMultiplier + 0.1, 2.0)
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Decrease Text Size") {
                    textSizeMultiplier = max(textSizeMultiplier - 0.1, 0.5)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Text Size") {
                    textSizeMultiplier = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)
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

struct AppPreferencesView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("textSizeMultiplier") private var textSizeMultiplier: Double = 1.0

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

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Text Size")
                            Spacer()
                            Text("\(Int(textSizeMultiplier * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $textSizeMultiplier, in: 0.5...2.0, step: 0.1)
                        HStack {
                            Text("Small")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Large")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Adjust the text size throughout the app. You can also use ⌘+ and ⌘- to adjust text size.")
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

// Environment key for text size multiplier
private struct TextSizeMultiplierKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var textSizeMultiplier: Double {
        get { self[TextSizeMultiplierKey.self] }
        set { self[TextSizeMultiplierKey.self] = newValue }
    }
}

// Font extension to apply text size multiplier
extension Font {
    func scaledFont(multiplier: Double) -> Font {
        // This is a helper that can be used to scale fonts
        return self
    }
}

// View extension to easily apply scaled fonts
extension View {
    func scaledFont(_ font: Font, multiplier: Double) -> some View {
        let scaledSize: CGFloat
        switch font {
        case .largeTitle:
            scaledSize = 34 * multiplier
        case .title:
            scaledSize = 28 * multiplier
        case .title2:
            scaledSize = 22 * multiplier
        case .title3:
            scaledSize = 20 * multiplier
        case .headline:
            scaledSize = 17 * multiplier
        case .body:
            scaledSize = 17 * multiplier
        case .callout:
            scaledSize = 16 * multiplier
        case .subheadline:
            scaledSize = 15 * multiplier
        case .footnote:
            scaledSize = 13 * multiplier
        case .caption:
            scaledSize = 12 * multiplier
        case .caption2:
            scaledSize = 11 * multiplier
        default:
            scaledSize = 17 * multiplier
        }
        return self.font(.system(size: scaledSize))
    }
}
#endif
