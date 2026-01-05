import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var store: RecipeStore
    @State var recipe: Recipe
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color {
        if let categoryID = recipe.categoryID,
           let category = store.categories.first(where: { $0.id == categoryID }) {
            return category.color
        }
        return .accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Recipe Image (edge-to-edge)
                if let imageData = recipe.imageData,
                   let image = createPlatformImage(from: imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                }

                // Content with padding
                VStack(alignment: .leading, spacing: 20) {
                    // Title and Rating
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(.largeTitle)
                        .bold()
                    
                    HStack(spacing: 16) {
                        // Star Rating
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                                    .foregroundColor(star <= recipe.rating ? .yellow : .gray)
                            }
                        }
                        
                        // Times
                        if recipe.prepDuration > 0 {
                            Label(formatDuration(recipe.prepDuration), systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if recipe.cookDuration > 0 {
                            Label(formatDuration(recipe.cookDuration), systemImage: "flame")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Source URL
                    if !recipe.sourceURL.isEmpty {
                        if let url = URL(string: recipe.sourceURL) {
                            Link(destination: url) {
                                Label("View Source", systemImage: "link")
                                    .font(.subheadline)
                                    .foregroundColor(accentColor)
                            }
                        }
                    }
                    
                    // Dates cooked
                    if !recipe.datesCooked.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cooked \(recipe.datesCooked.count) time\(recipe.datesCooked.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let lastCooked = recipe.datesCooked.max() {
                                Text("Last: \(lastCooked, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.title2)
                        .bold()
                    
                    ForEach($recipe.ingredients) { $ingredient in
                        Button(action: {
                            ingredient.isChecked.toggle()
                            store.saveRecipe(recipe)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: ingredient.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(ingredient.isChecked ? .green : .gray)
                                    .font(.title3)
                                
                                Text(ingredient.text)
                                    .foregroundColor(.primary)
                                    .strikethrough(ingredient.isChecked)
                                    .opacity(ingredient.isChecked ? 0.6 : 1.0)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                
                // Directions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Directions")
                        .font(.title2)
                        .bold()
                    
                    ForEach(recipe.directions.sorted(by: { $0.order < $1.order })) { direction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(direction.order + 1)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(accentColor))
                            
                            Text(direction.text)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                    }
                }
                
                // Notes
                if !recipe.notes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.title2)
                            .bold()
                        
                        Text(recipe.notes)
                            .foregroundColor(.secondary)
                    }
                }
                
                    // Mark as Cooked Button
                    Button(action: markAsCooked) {
                        Label("Mark as Cooked", systemImage: "checkmark.circle")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal)
                            .background(accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: shareRecipe) {
                        Label("Share Recipe", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            RecipeEditView(recipe: recipe)
        }
        .alert("Delete Recipe", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: deleteRecipe)
        } message: {
            Text("Are you sure you want to delete '\(recipe.title)'? This action cannot be undone.")
        }
        .onReceive(store.$recipes) { recipes in
            if let updated = recipes.first(where: { $0.id == recipe.id }) {
                recipe = updated
            }
        }
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
    
    private func markAsCooked() {
        store.addCookedDate(recipe)
    }
    
    private func shareRecipe() {
        // Create temporary file with .cookbook.json extension
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(recipe.title.replacingOccurrences(of: " ", with: "_")).cookbook.json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recipe)
            try data.write(to: fileURL)

            // Present share sheet
            #if os(iOS)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            #elseif os(macOS)
            let picker = NSSharingServicePicker(items: [fileURL])
            if let view = NSApplication.shared.keyWindow?.contentView {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
            #endif
        } catch {
            print("Error sharing recipe: \(error)")
        }
    }

    private func deleteRecipe() {
        store.deleteRecipe(recipe)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe(
            title: "Pasta Carbonara",
            rating: 5,
            prepDuration: 600,
            cookDuration: 900
        ))
    }
    .environmentObject(RecipeStore())
}
