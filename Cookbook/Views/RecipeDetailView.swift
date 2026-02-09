import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var store: RecipeStore
    @State var recipe: Recipe
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var animatingCheckmarks: [Int: Bool] = [:]
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @Environment(\.textSizeMultiplier) private var textSizeMultiplier
    #endif

    private var accentColor: Color {
        if let categoryID = recipe.categoryID,
           let category = store.categories.first(where: { $0.id == categoryID }) {
            return category.color
        }
        return .accentColor
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width >= 900 {
            return 80
        } else if width >= 500 {
            return 40
        } else {
            return 20
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                // Recipe Image (edge-to-edge)
                if let imageData = recipe.imageData,
                   let image = createPlatformImage(from: imageData) {
                    Color.clear
                        .frame(height: 300)
                        .overlay {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                        .id("top")
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                        .id("top")
                }

                // Content with padding
                VStack(alignment: .leading, spacing: 20) {
                    // Title and Rating
                VStack(alignment: .leading, spacing: 8) {
                    #if os(macOS)
                    Text(recipe.title)
                        .font(.system(size: 34 * textSizeMultiplier))
                        .bold()
                    #else
                    Text(recipe.title)
                        .font(.largeTitle)
                        .bold()
                    #endif
                    
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
                    #if os(macOS)
                    Text("Ingredients")
                        .font(.system(size: 22 * textSizeMultiplier))
                        .bold()
                    #else
                    Text("Ingredients")
                        .font(.title2)
                        .bold()
                    #endif

                    ForEach(Array($recipe.ingredients.enumerated()), id: \.element.id) { index, $ingredient in
                        Button(action: {
                            ingredient.isChecked.toggle()
                            store.saveRecipe(recipe)
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Image(systemName: ingredient.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(ingredient.isChecked ? .green : .gray)
                                        .font(.title3)

                                    // Overlay animated checkmark
                                    if animatingCheckmarks[index] != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                            .scaleEffect(animatingCheckmarks[index] == true ? 2.5 : 1.0)
                                            .opacity(animatingCheckmarks[index] == true ? 0.0 : 1.0)
                                    }
                                }

                                #if os(macOS)
                                Text(ingredient.text.sanitizedForDisplay)
                                    .font(.system(size: 17 * textSizeMultiplier))
                                    .foregroundColor(.primary)
                                    .strikethrough(ingredient.isChecked)
                                    .opacity(ingredient.isChecked ? 0.6 : 1.0)
                                #else
                                Text(ingredient.text.sanitizedForDisplay)
                                    .foregroundColor(.primary)
                                    .strikethrough(ingredient.isChecked)
                                    .opacity(ingredient.isChecked ? 0.6 : 1.0)
                                #endif

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                
                // Directions
                VStack(alignment: .leading, spacing: 12) {
                    #if os(macOS)
                    Text("Directions")
                        .font(.system(size: 22 * textSizeMultiplier))
                        .bold()
                    #else
                    Text("Directions")
                        .font(.title2)
                        .bold()
                    #endif
                    
                    ForEach(recipe.directions.sorted(by: { $0.order < $1.order })) { direction in
                        HStack(alignment: .top, spacing: 12) {
                            #if os(macOS)
                            Text("\(direction.order + 1)")
                                .font(.system(size: 17 * textSizeMultiplier))
                                .foregroundColor(.white)
                                .frame(width: 28 * textSizeMultiplier, height: 28 * textSizeMultiplier)
                                .background(Circle().fill(accentColor))

                            Text(direction.text.sanitizedForDisplay)
                                .font(.system(size: 17 * textSizeMultiplier))
                            #else
                            Text("\(direction.order + 1)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(accentColor))

                            Text(direction.text.sanitizedForDisplay)
                            #endif

                            Spacer()
                        }
                    }
                }
                
                // Notes
                if !recipe.notes.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        #if os(macOS)
                        Text("Notes")
                            .font(.system(size: 22 * textSizeMultiplier))
                            .bold()

                        Text(recipe.notes.sanitizedForDisplay)
                            .font(.system(size: 17 * textSizeMultiplier))
                            .foregroundColor(.secondary)
                        #else
                        Text("Notes")
                            .font(.title2)
                            .bold()

                        Text(recipe.notes.sanitizedForDisplay)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        #endif
                    }
                }
                
                    // Mark as Cooked Button
                    Button(action: { markAsCooked(scrollProxy: proxy) }) {
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
                .padding(.vertical)
                .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    Text(store.cookbook.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            #endif
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
    
    private func markAsCooked(scrollProxy: ScrollViewProxy) {
        // Scroll to the top
        withAnimation(.easeInOut(duration: 0.5)) {
            scrollProxy.scrollTo("top", anchor: .top)
        }

        // Wait for scroll to complete, then animate only the checked ingredients
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Animate only checkmarks that are currently checked
            for i in 0..<recipe.ingredients.count {
                if recipe.ingredients[i].isChecked {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                        // Create the overlay at starting state (scale 1.0, opacity 1.0)
                        animatingCheckmarks[i] = false

                        // Reset the actual checkbox immediately
                        recipe.ingredients[i].isChecked = false

                        // Start the animation after a tiny delay to ensure the overlay is rendered
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            withAnimation(.easeIn(duration: 0.4)) {
                                animatingCheckmarks[i] = true
                            }
                        }

                        // Remove from animating set after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            animatingCheckmarks[i] = nil
                        }
                    }
                }
            }

            // Save the recipe and add cooked date after all animations
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(recipe.ingredients.count) * 0.1 + 0.6) {
                store.saveRecipe(recipe)
                store.addCookedDate(recipe)
            }
        }
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
