import Foundation
import Vision
import NaturalLanguage

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

struct RecipeOCRScanner {

    // MARK: - Line Classification

    enum LineClassification: String, CaseIterable {
        case ingredient
        case direction
        case title
        case note
        case skip

        var label: String {
            switch self {
            case .ingredient: return "Ingr."
            case .direction: return "Step"
            case .title: return "Title"
            case .note: return "Note"
            case .skip: return "Skip"
            }
        }
    }

    struct ClassifiedLine: Identifiable {
        let id = UUID()
        var text: String
        var classification: LineClassification
    }

    struct ScannedRecipe {
        var title: String
        var ingredients: [String]
        var directions: [String]
        var notes: String
    }

    enum ScanError: LocalizedError {
        case noTextFound
        case imageConversionFailed

        var errorDescription: String? {
            switch self {
            case .noTextFound:
                return "No text could be recognized in the scanned images."
            case .imageConversionFailed:
                return "Could not process the scanned image."
            }
        }
    }

    // MARK: - OCR Text Recognition

    static func recognizeText(from images: [PlatformImage]) async throws -> String {
        var allText: [String] = []

        for image in images {
            let text = try await recognizeText(from: image)
            allText.append(text)
        }

        let combined = allText.joined(separator: "\n\n")
        guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScanError.noTextFound
        }

        return combined
    }

    private static func recognizeText(from image: PlatformImage) async throws -> String {
        guard let cgImage = cgImage(from: image) else {
            throw ScanError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Sort by position: top to bottom, then left to right
                let sorted = observations.sorted { a, b in
                    let aY = 1 - a.boundingBox.midY
                    let bY = 1 - b.boundingBox.midY
                    if abs(aY - bY) < 0.01 {
                        return a.boundingBox.minX < b.boundingBox.minX
                    }
                    return aY < bY
                }

                let text = sorted.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func cgImage(from image: PlatformImage) -> CGImage? {
        #if os(iOS)
        return image.cgImage
        #elseif os(macOS)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    // MARK: - Line Classification (for interactive review)

    static func classifyLines(from text: String) -> [ClassifiedLine] {
        let rawLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var result: [ClassifiedLine] = []
        var foundTitle = false

        enum Section {
            case unknown, ingredients, directions, notes
        }
        var currentSection: Section = .unknown

        for line in rawLines {
            guard !line.isEmpty else { continue }

            let lower = line.lowercased()
            let stripped = lower
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip section headers
            if isIngredientsHeader(stripped) {
                currentSection = .ingredients
                result.append(ClassifiedLine(text: line, classification: .skip))
                continue
            } else if isDirectionsHeader(stripped) {
                currentSection = .directions
                result.append(ClassifiedLine(text: line, classification: .skip))
                continue
            } else if isNotesHeader(stripped) {
                currentSection = .notes
                result.append(ClassifiedLine(text: line, classification: .skip))
                continue
            }

            // Skip metadata lines (servings, yield, time, etc.)
            if isMetadataLine(lower) {
                result.append(ClassifiedLine(text: line, classification: .skip))
                continue
            }

            // Classify based on current section context
            switch currentSection {
            case .unknown:
                if !foundTitle && line.count >= 2 {
                    result.append(ClassifiedLine(text: line, classification: .title))
                    foundTitle = true
                } else if looksLikeIngredient(line) {
                    result.append(ClassifiedLine(text: line, classification: .ingredient))
                } else if isDirectionLike(line) {
                    result.append(ClassifiedLine(text: line, classification: .direction))
                } else {
                    result.append(ClassifiedLine(text: line, classification: .skip))
                }

            case .ingredients:
                let cleaned = cleanIngredientLine(line)
                if !cleaned.isEmpty {
                    result.append(ClassifiedLine(text: cleaned, classification: .ingredient))
                }

            case .directions:
                let cleaned = cleanDirectionLine(line)
                if !cleaned.isEmpty {
                    result.append(ClassifiedLine(text: cleaned, classification: .direction))
                }

            case .notes:
                result.append(ClassifiedLine(text: line, classification: .note))
            }
        }

        // If no title was found among unknown lines, pick the first non-skip line
        if !result.contains(where: { $0.classification == .title }) {
            if let firstIdx = result.firstIndex(where: { $0.classification != .skip }) {
                result[firstIdx].classification = .title
            }
        }

        // If no section headers were found (all unknown), use heuristic classification
        if currentSection == .unknown {
            return classifyHeuristically(result)
        }

        return result
    }

    /// Build a recipe from user-reviewed classified lines.
    /// Merges consecutive direction lines into paragraph-level steps.
    static func buildRecipe(from lines: [ClassifiedLine]) -> ScannedRecipe {
        var title = ""
        var ingredients: [String] = []
        var directionParagraphs: [String] = []
        var noteLines: [String] = []

        var currentDirectionParagraph = ""

        for line in lines {
            switch line.classification {
            case .title:
                if title.isEmpty {
                    title = line.text
                }

            case .ingredient:
                // Flush any in-progress direction paragraph
                if !currentDirectionParagraph.isEmpty {
                    directionParagraphs.append(currentDirectionParagraph)
                    currentDirectionParagraph = ""
                }
                ingredients.append(cleanIngredientLine(line.text))

            case .direction:
                let cleaned = cleanDirectionLine(line.text)
                guard !cleaned.isEmpty else { continue }

                // Start a new paragraph if this line has a step number
                let startsNewStep = cleaned.range(
                    of: #"^\s*(?:step\s*)?\d+[.):\s]"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil

                if startsNewStep && !currentDirectionParagraph.isEmpty {
                    directionParagraphs.append(currentDirectionParagraph)
                    currentDirectionParagraph = cleanDirectionLine(cleaned)
                } else if currentDirectionParagraph.isEmpty {
                    currentDirectionParagraph = cleaned
                } else {
                    // Merge into current paragraph
                    currentDirectionParagraph += " " + cleaned
                }

            case .note:
                // Flush direction paragraph
                if !currentDirectionParagraph.isEmpty {
                    directionParagraphs.append(currentDirectionParagraph)
                    currentDirectionParagraph = ""
                }
                noteLines.append(line.text)

            case .skip:
                // Flush direction paragraph at gaps
                if !currentDirectionParagraph.isEmpty {
                    directionParagraphs.append(currentDirectionParagraph)
                    currentDirectionParagraph = ""
                }
            }
        }

        // Flush remaining direction paragraph
        if !currentDirectionParagraph.isEmpty {
            directionParagraphs.append(currentDirectionParagraph)
        }

        return ScannedRecipe(
            title: title.isEmpty ? "Scanned Recipe" : title,
            ingredients: ingredients,
            directions: directionParagraphs,
            notes: noteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Metadata Detection

    private static func isMetadataLine(_ lower: String) -> Bool {
        let metadataPatterns = [
            #"^serves?\s*:?\s*\d"#,
            #"^servings?\s*:?\s*\d"#,
            #"^yield\s*:"#,
            #"^makes?\s+\d"#,
            #"^prep\s*(?:aration)?\s*time\s*:"#,
            #"^cook\s*(?:ing)?\s*time\s*:"#,
            #"^total\s*time\s*:"#,
            #"^active\s*time\s*:"#,
            #"^ready\s*in\s*:"#,
            #"^difficulty\s*:"#,
            #"^cuisine\s*:"#,
            #"^course\s*:"#,
            #"^category\s*:"#,
            #"^calories\s*:"#,
            #"^nutrition"#,
            #"^source\s*:"#,
            #"^adapted\s+from"#,
            #"^photograph"#,
            #"^page\s+\d"#,
        ]

        return metadataPatterns.contains { pattern in
            lower.range(of: pattern, options: .regularExpression) != nil
        }
    }

    // MARK: - Section Header Detection

    private static func isIngredientsHeader(_ text: String) -> Bool {
        let patterns = [
            "ingredients", "ingredient list", "what you need",
            "you will need", "you'll need"
        ]
        return patterns.contains(where: { text == $0 || text.hasPrefix($0) })
    }

    private static func isDirectionsHeader(_ text: String) -> Bool {
        let patterns = [
            "directions", "instructions", "method", "steps",
            "preparation", "how to make", "procedure"
        ]
        return patterns.contains(where: { text == $0 || text.hasPrefix($0) })
    }

    private static func isNotesHeader(_ text: String) -> Bool {
        let patterns = [
            "notes", "tips", "chef's notes", "cook's notes",
            "serving suggestions", "variations"
        ]
        return patterns.contains(where: { text == $0 || text.hasPrefix($0) })
    }

    // MARK: - Line Cleaning

    private static func cleanIngredientLine(_ line: String) -> String {
        var cleaned = line
        cleaned = cleaned.replacingOccurrences(
            of: #"^[\s]*[-•·▪▸►◦○●☐☑✓✔]\s*"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private static func cleanDirectionLine(_ line: String) -> String {
        var cleaned = line
        cleaned = cleaned.replacingOccurrences(
            of: #"^[\s]*(?:step\s*)?(\d+)[.):\s]+\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"^[\s]*[-•·▪▸►◦○●]\s*"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Heuristic Classification (No Section Headers)

    private static func classifyHeuristically(_ lines: [ClassifiedLine]) -> [ClassifiedLine] {
        var result = lines

        for i in result.indices {
            if result[i].classification == .title { continue }
            if result[i].classification == .skip && isMetadataLine(result[i].text.lowercased()) { continue }

            let text = result[i].text
            if looksLikeIngredient(text) {
                result[i].classification = .ingredient
            } else if isDirectionLike(text) {
                result[i].classification = .direction
            } else {
                result[i].classification = .skip
            }
        }

        return result
    }

    private static let measurementPattern = #"(?:\d[\d\/\.\s]*(?:cups?|tbsp|tsp|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|grams?|g\b|kg|ml|liters?|litres?|pinch|dash|cloves?|cans?|packages?|pkg|sticks?|slices?|pieces?|bunch|head|medium|large|small|whole|halves|half|quarters?|inch))"#

    static func looksLikeIngredient(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.range(of: measurementPattern, options: .regularExpression) != nil
    }

    private static func isDirectionLike(_ line: String) -> Bool {
        let lower = line.lowercased()

        if lower.range(of: #"^\s*(?:step\s*)?\d+[.):\s]"#, options: .regularExpression) != nil {
            return true
        }

        let cookingVerbs: Set<String> = [
            "preheat", "heat", "mix", "stir", "combine", "add", "pour",
            "bake", "cook", "boil", "simmer", "sauté", "saute", "fry",
            "roast", "grill", "broil", "blend", "whisk", "fold",
            "chop", "dice", "slice", "mince", "cut", "trim",
            "season", "sprinkle", "drizzle", "brush", "coat",
            "let", "allow", "set", "place", "put", "remove",
            "serve", "garnish", "transfer", "drain", "rinse",
            "knead", "roll", "spread", "cover", "refrigerate",
            "marinate", "toss", "beat", "cream", "melt",
            "bring", "reduce", "strain", "cool", "warm"
        ]

        let firstWord = lower.components(separatedBy: .whitespaces).first ?? ""
        if cookingVerbs.contains(firstWord) {
            return true
        }

        if line.count > 50 {
            return true
        }

        return false
    }
}
