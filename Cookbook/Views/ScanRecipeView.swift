import SwiftUI

#if os(iOS)
import VisionKit
#endif

struct ScanRecipeView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    @State private var scannedImages: [PlatformImage] = []
    @State private var classifiedLines: [RecipeOCRScanner.ClassifiedLine] = []
    @State private var parsedRecipe: RecipeOCRScanner.ScannedRecipe?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingCamera = true

    private enum Phase {
        case scanning
        case classifying
        case preview
    }

    private var phase: Phase {
        if parsedRecipe != nil {
            return .preview
        } else if !classifiedLines.isEmpty {
            return .classifying
        } else {
            return .scanning
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(iOS)
                if showingCamera && scannedImages.isEmpty {
                    DocumentCameraView(
                        scannedImages: $scannedImages,
                        showingCamera: $showingCamera,
                        onCancel: { dismiss() },
                        onScanComplete: { processScannedImages() }
                    )
                    .ignoresSafeArea()
                } else {
                    iOSContent
                }
                #else
                macOSContent
                #endif
            }
            .navigationTitle(phase == .classifying ? "Review Lines" : "Scan Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                if !showingCamera || !scannedImages.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                if phase == .preview {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit Lines") {
                            parsedRecipe = nil
                        }
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                #endif
            }
        }
    }

    // MARK: - iOS Content

    #if os(iOS)
    private var iOSContent: some View {
        Form {
            scannedPagesSection

            if isProcessing {
                Section {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Recognizing text...")
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            }

            switch phase {
            case .scanning:
                EmptyView()

            case .classifying:
                classificationSection
                buildPreviewButton

            case .preview:
                if let parsed = parsedRecipe {
                    previewSection(parsed)
                    ingredientsPreview(parsed)
                    directionsPreview(parsed)
                    if !parsed.notes.isEmpty {
                        notesPreview(parsed)
                    }
                    saveSection
                }
            }
        }
    }

    private var scannedPagesSection: some View {
        Section("Scanned Pages") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(scannedImages.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Button(action: { showingCamera = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                            Text("Add\nPages")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 80, height: 110)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    #endif

    // MARK: - macOS Content

    #if os(macOS)
    private var macOSContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Select Images")
                        .font(.headline)
                    Text("Choose photos of recipe pages to scan and extract text.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: pickImagesOnMac) {
                        Label("Choose Images", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !scannedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(scannedImages.enumerated()), id: \.offset) { _, image in
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                if isProcessing {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Recognizing text...")
                    }
                }

                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                switch phase {
                case .scanning:
                    EmptyView()

                case .classifying:
                    classificationSection
                    buildPreviewButton

                case .preview:
                    if let parsed = parsedRecipe {
                        previewSection(parsed)
                        ingredientsPreview(parsed)
                        directionsPreview(parsed)
                        if !parsed.notes.isEmpty {
                            notesPreview(parsed)
                        }
                        saveSection
                    }
                }
            }
            .padding()
            .frame(minWidth: 500, maxWidth: 700)
        }
    }

    private func pickImagesOnMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let images = panel.urls.compactMap { url -> NSImage? in
                NSImage(contentsOf: url)
            }
            scannedImages = images
            if !images.isEmpty {
                processScannedImages()
            }
        }
    }
    #endif

    // MARK: - Classification Section (shared)

    private var classificationSection: some View {
        let header = "Tap a label to reclassify"
        let content = ForEach(Array($classifiedLines.enumerated()), id: \.element.id) { index, $line in
            classifiedLineRow(line: $line)
        }

        #if os(macOS)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Recognized Lines")
                .font(.headline)
            Text(header)
                .font(.caption)
                .foregroundColor(.secondary)
            content
        }
        .eraseToAnyView()
        #else
        return Section {
            content
        } header: {
            Text("Recognized Lines")
        } footer: {
            Text(header)
        }
        .eraseToAnyView()
        #endif
    }

    private func classifiedLineRow(line: Binding<RecipeOCRScanner.ClassifiedLine>) -> some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(RecipeOCRScanner.LineClassification.allCases, id: \.self) { classification in
                    Button(action: {
                        line.wrappedValue.classification = classification
                    }) {
                        HStack {
                            Text(classification.label)
                            if line.wrappedValue.classification == classification {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(line.wrappedValue.classification.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minWidth: 44)
                    .background(classificationColor(line.wrappedValue.classification).opacity(0.15))
                    .foregroundColor(classificationColor(line.wrappedValue.classification))
                    .clipShape(Capsule())
            }

            Text(line.wrappedValue.text)
                .font(.subheadline)
                .foregroundColor(line.wrappedValue.classification == .skip ? .secondary : .primary)
                .strikethrough(line.wrappedValue.classification == .skip)
                .lineLimit(3)
        }
    }

    private func classificationColor(_ classification: RecipeOCRScanner.LineClassification) -> Color {
        switch classification {
        case .ingredient: return .green
        case .direction: return .blue
        case .title: return .purple
        case .note: return .orange
        case .skip: return .gray
        }
    }

    private var buildPreviewButton: some View {
        #if os(macOS)
        HStack {
            Spacer()
            Button(action: buildPreview) {
                Label("Continue", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        #else
        Section {
            Button(action: buildPreview) {
                Label("Continue", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity)
            }
            .font(.headline)
        }
        #endif
    }

    // MARK: - Preview Sections

    private func previewSection(_ parsed: RecipeOCRScanner.ScannedRecipe) -> some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            LabeledContent("Title", value: parsed.title)
            LabeledContent("Ingredients", value: "\(parsed.ingredients.count)")
            LabeledContent("Steps", value: "\(parsed.directions.count)")
        }
        #else
        Section("Preview") {
            LabeledContent("Title", value: parsed.title)
            LabeledContent("Ingredients", value: "\(parsed.ingredients.count)")
            LabeledContent("Steps", value: "\(parsed.directions.count)")
        }
        #endif
    }

    @ViewBuilder
    private func ingredientsPreview(_ parsed: RecipeOCRScanner.ScannedRecipe) -> some View {
        if !parsed.ingredients.isEmpty {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingredients")
                    .font(.headline)
                ForEach(parsed.ingredients, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.subheadline)
                }
            }
            #else
            Section("Ingredients") {
                ForEach(parsed.ingredients, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.subheadline)
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func directionsPreview(_ parsed: RecipeOCRScanner.ScannedRecipe) -> some View {
        if !parsed.directions.isEmpty {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
                Text("Directions")
                    .font(.headline)
                ForEach(Array(parsed.directions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            #else
            Section("Directions") {
                ForEach(Array(parsed.directions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func notesPreview(_ parsed: RecipeOCRScanner.ScannedRecipe) -> some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(parsed.notes)
                .font(.subheadline)
        }
        #else
        Section("Notes") {
            Text(parsed.notes)
                .font(.subheadline)
        }
        #endif
    }

    private var saveSection: some View {
        #if os(macOS)
        HStack {
            Spacer()
            Button(action: saveRecipe) {
                Label("Save Recipe", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        #else
        Section {
            Button(action: saveRecipe) {
                Label("Save Recipe", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .font(.headline)
        }
        #endif
    }

    // MARK: - Actions

    private func processScannedImages() {
        isProcessing = true
        errorMessage = nil
        classifiedLines = []
        parsedRecipe = nil

        Task {
            do {
                let text = try await RecipeOCRScanner.recognizeText(from: scannedImages)
                await MainActor.run {
                    classifiedLines = RecipeOCRScanner.classifyLines(from: text)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func buildPreview() {
        parsedRecipe = RecipeOCRScanner.buildRecipe(from: classifiedLines)
    }

    private func saveRecipe() {
        guard let parsed = parsedRecipe else { return }

        let recipe = Recipe(
            title: parsed.title,
            ingredients: parsed.ingredients.map { Ingredient(text: $0) },
            directions: parsed.directions.enumerated().map { Direction(text: $1, order: $0 + 1) },
            notes: parsed.notes
        )

        store.saveRecipe(recipe)
        dismiss()
    }
}

// MARK: - AnyView Helper

private extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

// MARK: - Document Camera (iOS)

#if os(iOS)
struct DocumentCameraView: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Binding var showingCamera: Bool
    var onCancel: () -> Void
    var onScanComplete: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView

        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images = parent.scannedImages
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            parent.scannedImages = images
            parent.showingCamera = false
            parent.onScanComplete()
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            parent.showingCamera = false
            if parent.scannedImages.isEmpty {
                parent.onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.showingCamera = false
            if parent.scannedImages.isEmpty {
                parent.onCancel()
            }
        }
    }
}
#endif

#Preview {
    ScanRecipeView()
        .environmentObject(RecipeStore())
}
