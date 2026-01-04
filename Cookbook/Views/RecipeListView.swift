import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var searchText = ""
    @State private var showingAddRecipe = false
    
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return store.recipes
        }
        return store.recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        RecipeRowView(recipe: recipe)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle("Cookbook")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddRecipe = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                RecipeEditView(recipe: Recipe())
            }
        }
    }
    
    private func deleteRecipes(at offsets: IndexSet) {
        offsets.forEach { index in
            let recipe = filteredRecipes[index]
            store.deleteRecipe(recipe)
        }
    }
}

struct RecipeRowView: View {
    let recipe: Recipe
    
    var body: some View {
        HStack(spacing: 12) {
            // Recipe image thumbnail
            if let imageData = recipe.imageData,
               let image = createPlatformImage(from: imageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if recipe.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<recipe.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    if recipe.prepDuration > 0 || recipe.cookDuration > 0 {
                        Text(formatTotalTime(prep: recipe.prepDuration, cook: recipe.cookDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !recipe.datesCooked.isEmpty {
                    Text("Cooked \(recipe.datesCooked.count) time\(recipe.datesCooked.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func createPlatformImage(from data: Data) -> Image? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
    
    private func formatTotalTime(prep: TimeInterval, cook: TimeInterval) -> String {
        let total = Int((prep + cook) / 60)
        if total < 60 {
            return "\(total) min"
        } else {
            let hours = total / 60
            let minutes = total % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}

#Preview {
    RecipeListView()
        .environmentObject(RecipeStore())
}
