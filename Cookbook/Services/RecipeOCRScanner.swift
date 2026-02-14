import Foundation
import Vision
import NaturalLanguage

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RecipeOCRScanner {

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

    // MARK: - Recipe Parsing

    static func parseRecipe(from text: String) -> ScannedRecipe {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var title = ""
        var ingredients: [String] = []
        var directions: [String] = []
        var notes = ""

        enum Section {
            case unknown, ingredients, directions, notes
        }

        var currentSection: Section = .unknown
        var unknownLines: [String] = []

        for line in lines {
            let lower = line.lowercased()
            let stripped = lower
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Detect section headers
            if isIngredientsHeader(stripped) {
                currentSection = .ingredients
                continue
            } else if isDirectionsHeader(stripped) {
                currentSection = .directions
                continue
            } else if isNotesHeader(stripped) {
                currentSection = .notes
                continue
            }

            guard !line.isEmpty else { continue }

            switch currentSection {
            case .unknown:
                unknownLines.append(line)

            case .ingredients:
                let cleaned = cleanIngredientLine(line)
                if !cleaned.isEmpty {
                    ingredients.append(cleaned)
                }

            case .directions:
                let cleaned = cleanDirectionLine(line)
                if !cleaned.isEmpty {
                    directions.append(cleaned)
                }

            case .notes:
                if notes.isEmpty {
                    notes = line
                } else {
                    notes += "\n" + line
                }
            }
        }

        // If no section headers were found, use heuristic parsing
        if ingredients.isEmpty && directions.isEmpty {
            let nonEmpty = lines.filter { !$0.isEmpty }
            return parseRecipeHeuristically(lines: nonEmpty)
        }

        title = extractTitle(from: unknownLines)

        return ScannedRecipe(
            title: title,
            ingredients: ingredients,
            directions: directions,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
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
        // Remove bullet points, dashes, checkboxes
        cleaned = cleaned.replacingOccurrences(
            of: #"^[\s]*[-•·▪▸►◦○●☐☑✓✔]\s*"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private static func cleanDirectionLine(_ line: String) -> String {
        var cleaned = line
        // Remove step numbers like "1.", "1)", "Step 1:", "Step 1."
        cleaned = cleaned.replacingOccurrences(
            of: #"^[\s]*(?:step\s*)?(\d+)[.):\s]+\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Remove bullet points
        cleaned = cleaned.replacingOccurrences(
            of: #"^[\s]*[-•·▪▸►◦○●]\s*"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Heuristic Parsing (No Section Headers)

    private static func parseRecipeHeuristically(lines: [String]) -> ScannedRecipe {
        var title = ""
        var ingredients: [String] = []
        var directions: [String] = []

        if let firstLine = lines.first {
            title = firstLine
        }

        let measurementPattern = #"(?:\d[\d\/\.\s]*(?:cups?|tbsp|tsp|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|grams?|g\b|kg|ml|liters?|litres?|pinch|dash|cloves?|cans?|packages?|pkg|sticks?|slices?|pieces?|bunch|head|medium|large|small|whole|halves|half|quarters?|inch))"#

        for (index, line) in lines.enumerated() {
            guard index > 0 else { continue }

            let lower = line.lowercased()

            if lower.range(of: measurementPattern, options: .regularExpression) != nil {
                ingredients.append(cleanIngredientLine(line))
            } else if isDirectionLike(line) {
                directions.append(cleanDirectionLine(line))
            }
        }

        // If heuristics didn't split well, put remaining lines as directions
        if ingredients.isEmpty && directions.isEmpty {
            directions = Array(lines.dropFirst())
        }

        return ScannedRecipe(
            title: title,
            ingredients: ingredients,
            directions: directions,
            notes: ""
        )
    }

    private static func isDirectionLike(_ line: String) -> Bool {
        let lower = line.lowercased()

        // Starts with step number
        if lower.range(of: #"^\s*(?:step\s*)?\d+[.):\s]"#, options: .regularExpression) != nil {
            return true
        }

        // Starts with a cooking verb
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

        // Sentence-length text (longer lines are more likely directions)
        if line.count > 50 {
            return true
        }

        return false
    }

    private static func extractTitle(from lines: [String]) -> String {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 2
                && !trimmed.lowercased().hasPrefix("serves")
                && !trimmed.lowercased().hasPrefix("yield")
                && !trimmed.lowercased().hasPrefix("makes") {
                return trimmed
            }
        }
        return lines.first ?? "Scanned Recipe"
    }
}
