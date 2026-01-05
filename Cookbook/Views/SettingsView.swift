import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var cookbookName: String = ""
    @State private var showingCookbookSwitcher = false

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    saveCookbookName()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section {
                    Button(action: {
                        showingCookbookSwitcher = true
                    }) {
                        HStack {
                            Text("Manage Cookbooks")
                            Spacer()
                            Text("\(store.availableCookbooks.count) total")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Cookbooks")
                } footer: {
                    if hasDuplicateNames {
                        Text("⚠️ You have multiple cookbooks with the same name. Consider renaming them for clarity.")
                            .foregroundColor(.orange)
                    }
                }

                Section("Current Cookbook") {
                    TextField("Cookbook Name", text: $cookbookName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Recipes")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(store.recipes.count)")
                    }

                    HStack {
                        Text("Categories")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(store.categories.count)")
                    }

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(store.cookbook.dateCreated, style: .date)
                    }

                    HStack {
                        Text("Last Modified")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(store.cookbook.dateModified, style: .date)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showingCookbookSwitcher) {
            CookbookSwitcherView()
        }
        .onAppear {
            cookbookName = store.cookbook.name
        }
        #else
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        showingCookbookSwitcher = true
                    }) {
                        HStack {
                            Text("Manage Cookbooks")
                            Spacer()
                            Text("\(store.availableCookbooks.count) total")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Cookbooks")
                } footer: {
                    if hasDuplicateNames {
                        Text("⚠️ You have multiple cookbooks with the same name. Consider renaming them for clarity.")
                            .foregroundColor(.orange)
                    }
                }

                Section("Current Cookbook") {
                    TextField("Cookbook Name", text: $cookbookName)
                        .textInputAutocapitalization(.words)

                    HStack {
                        Text("Recipes")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(store.recipes.count)")
                    }

                    HStack {
                        Text("Categories")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(store.categories.count)")
                    }

                    HStack {
                        Text("Created")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(store.cookbook.dateCreated, style: .date)
                    }

                    HStack {
                        Text("Last Modified")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(store.cookbook.dateModified, style: .date)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveCookbookName()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCookbookSwitcher) {
                CookbookSwitcherView()
            }
            .onAppear {
                cookbookName = store.cookbook.name
            }
        }
        #endif
    }

    private var hasDuplicateNames: Bool {
        let names = store.availableCookbooks.map { $0.name }
        return names.count != Set(names).count
    }

    private func saveCookbookName() {
        let trimmedName = cookbookName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            store.cookbook.name = trimmedName
            store.saveCookbook()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(RecipeStore())
}
