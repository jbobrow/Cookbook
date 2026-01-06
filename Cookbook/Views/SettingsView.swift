import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var cookbookName: String = ""

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
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
                            .onChange(of: cookbookName) { oldValue, newValue in
                                let trimmedName = newValue.trimmingCharacters(in: .whitespaces)
                                if !trimmedName.isEmpty {
                                    store.cookbook.name = trimmedName
                                    store.saveCookbook()
                                }
                            }
                            .onSubmit {
                                dismiss()
                            }

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

                if hasDuplicateNames {
                    Text("⚠️ You have multiple cookbooks with the same name. Consider renaming them for clarity.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 400)
        #endif
        .onAppear {
            cookbookName = store.cookbook.name
        }
        #else
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cookbook Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .center) {
                        TextField("", text: $cookbookName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .onChange(of: cookbookName) { oldValue, newValue in
                                let trimmedName = newValue.trimmingCharacters(in: .whitespaces)
                                if !trimmedName.isEmpty {
                                    store.cookbook.name = trimmedName
                                    store.saveCookbook()
                                }
                            }
                            .onSubmit {
                                dismiss()
                            }

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

                if hasDuplicateNames {
                    Text("⚠️ You have multiple cookbooks with the same name. Consider renaming them for clarity.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .onAppear {
            cookbookName = store.cookbook.name
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
