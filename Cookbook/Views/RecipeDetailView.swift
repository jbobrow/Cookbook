import SwiftUI
import EventKit

struct RecipeDetailView: View {
    @EnvironmentObject var store: RecipeStore
    @State var recipe: Recipe
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var ingredientToAddToReminders: Ingredient?
    @State private var remindersAlertMessage: String?
    @State private var showingCookedConfirmation = false
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
            ZStack {
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

                    ForEach($recipe.ingredients) { $ingredient in
                        Button(action: {
                            ingredient.isChecked.toggle()
                            store.saveRecipe(recipe)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: ingredient.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(ingredient.isChecked ? .green : .gray)
                                    .font(.title3)

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
                        .contextMenu {
                            Button(action: {
                                ingredientToAddToReminders = ingredient
                            }) {
                                Label("Add to Reminders", systemImage: "list.bullet")
                            }
                        }
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
                    
                    ForEach($recipe.directions.sorted(by: { $0.wrappedValue.order < $1.wrappedValue.order })) { $direction in
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                direction.isCompleted.toggle()
                                store.saveRecipe(recipe)
                            }) {
                                #if os(macOS)
                                Group {
                                    if direction.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14 * textSizeMultiplier, weight: .bold))
                                            .foregroundColor(accentColor)
                                            .frame(width: 28 * textSizeMultiplier, height: 28 * textSizeMultiplier)
                                    } else {
                                        Text("\(direction.order + 1)")
                                            .font(.system(size: 17 * textSizeMultiplier))
                                            .foregroundColor(.white)
                                            .frame(width: 28 * textSizeMultiplier, height: 28 * textSizeMultiplier)
                                            .background(Circle().fill(accentColor))
                                    }
                                }
                                #else
                                Group {
                                    if direction.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(accentColor)
                                            .frame(width: 28, height: 28)
                                    } else {
                                        Text("\(direction.order + 1)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(accentColor))
                                    }
                                }
                                #endif
                            }
                            .buttonStyle(.plain)

                            #if os(macOS)
                            Text(direction.text.sanitizedForDisplay)
                                .font(.system(size: 17 * textSizeMultiplier))
                                .foregroundColor(direction.isCompleted ? .secondary : .primary)
                            #else
                            Text(direction.text.sanitizedForDisplay)
                                .foregroundColor(direction.isCompleted ? .secondary : .primary)
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

            // "Marked as Cooked" toast overlay
            if showingCookedConfirmation {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(accentColor)
                        .symbolEffect(.bounce, value: showingCookedConfirmation)
                    Text("Marked as Cooked")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Reset and ready for next time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
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
        .confirmationDialog(
            "Add to Reminders",
            isPresented: Binding(
                get: { ingredientToAddToReminders != nil },
                set: { if !$0 { ingredientToAddToReminders = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let ingredient = ingredientToAddToReminders {
                Button("Add \"\(ingredient.text.sanitizedForDisplay)\"") {
                    addIngredientToReminders(ingredient)
                }
            }
            Button("Cancel", role: .cancel) {
                ingredientToAddToReminders = nil
            }
        }
        .alert("Reminders", isPresented: Binding(
            get: { remindersAlertMessage != nil },
            set: { if !$0 { remindersAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { remindersAlertMessage = nil }
        } message: {
            if let message = remindersAlertMessage {
                Text(message)
            }
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
        // Scroll to top
        withAnimation(.easeInOut(duration: 0.4)) {
            scrollProxy.scrollTo("top", anchor: .top)
        }

        // Reset all ingredient checkmarks
        for i in 0..<recipe.ingredients.count {
            recipe.ingredients[i].isChecked = false
        }

        // Reset all direction completions
        for i in 0..<recipe.directions.count {
            recipe.directions[i].isCompleted = false
        }

        // Save and record cooked date
        store.addCookedDate(recipe)
        store.saveRecipe(recipe)

        // Show confirmation toast
        withAnimation(.spring(duration: 0.4)) {
            showingCookedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingCookedConfirmation = false
            }
        }
    }
    
    private func addIngredientToReminders(_ ingredient: Ingredient) {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToReminders { granted, error in
            DispatchQueue.main.async {
                guard granted, error == nil else {
                    remindersAlertMessage = "Please allow access to Reminders in Settings."
                    return
                }

                let reminder = EKReminder(eventStore: eventStore)
                reminder.title = ingredient.text.sanitizedForDisplay

                // Look for a "Groceries" list, fall back to default
                let calendars = eventStore.calendars(for: .reminder)
                if let groceriesList = calendars.first(where: { $0.title.localizedCaseInsensitiveContains("groceries") }) {
                    reminder.calendar = groceriesList
                } else {
                    reminder.calendar = eventStore.defaultCalendarForNewReminders()
                }

                do {
                    try eventStore.save(reminder, commit: true)
                    let listName = reminder.calendar?.title ?? "Reminders"
                    remindersAlertMessage = "Added to \(listName)."
                } catch {
                    remindersAlertMessage = "Failed to add reminder."
                }
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
