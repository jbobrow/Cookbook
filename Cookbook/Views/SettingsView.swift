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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cookbook Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .center) {
                        TextField("", text: $cookbookName)
                            .textFieldStyle(.roundedBorder)

                        Button(action: {
                            // Focus will be handled by tapping the text field
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                    }

                    // Stats below name
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("\(store.recipes.count) recipes")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("\(store.categories.count) categories")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .padding(.vertical, 8)

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

                if hasDuplicateNames {
                    Text("⚠️ You have multiple cookbooks with the same name. Consider renaming them for clarity.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding()
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            TextField("Cookbook Name", text: $cookbookName)
                                .textInputAutocapitalization(.words)

                            Button(action: {
                                // Focus will be handled by tapping the text field
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                Text("\(store.recipes.count) recipes")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text("\(store.categories.count) categories")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Current Cookbook")
                }

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
                } footer: {
                    if hasDuplicateNames {
                        Text("⚠️ You have multiple cookbooks with the same name. Consider renaming them for clarity.")
                            .foregroundColor(.orange)
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
