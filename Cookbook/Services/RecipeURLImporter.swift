import Foundation

struct RecipeURLImporter {

    struct ParsedRecipe {
        var title: String
        var ingredients: [String]
        var directions: [String]
        var sourceURL: String
        var imageURL: String?
        var prepDuration: TimeInterval
        var cookDuration: TimeInterval
        var notes: String
    }

    enum ImportError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL is not valid."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .parsingFailed:
                return "Could not find recipe data on this page."
            }
        }
    }

    static func importRecipe(from urlString: String) async throws -> ParsedRecipe {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw ImportError.invalidURL
        }

        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw ImportError.networkError(error)
        }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii) else {
            throw ImportError.parsingFailed
        }

        // Try JSON-LD structured data first (most recipe sites use this)
        if let recipe = parseJSONLD(html: html, sourceURL: urlString) {
            return recipe
        }

        // Fall back to Open Graph / meta tags for at least a title
        if let recipe = parseMetaTags(html: html, sourceURL: urlString) {
            return recipe
        }

        throw ImportError.parsingFailed
    }

    // MARK: - JSON-LD Parsing (Schema.org Recipe)

    private static func parseJSONLD(html: String, sourceURL: String) -> ParsedRecipe? {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange])
            guard let jsonData = jsonString.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: jsonData) else { continue }

            if let dict = json as? [String: Any] {
                if let recipe = extractRecipe(from: dict, sourceURL: sourceURL) {
                    return recipe
                }
                // Check @graph array (some sites wrap in a graph)
                if let graph = dict["@graph"] as? [[String: Any]] {
                    for item in graph {
                        if let recipe = extractRecipe(from: item, sourceURL: sourceURL) {
                            return recipe
                        }
                    }
                }
            } else if let array = json as? [[String: Any]] {
                for item in array {
                    if let recipe = extractRecipe(from: item, sourceURL: sourceURL) {
                        return recipe
                    }
                }
            }
        }

        return nil
    }

    private static func extractRecipe(from dict: [String: Any], sourceURL: String) -> ParsedRecipe? {
        let type = dict["@type"]
        let isRecipe: Bool
        if let typeString = type as? String {
            isRecipe = typeString == "Recipe"
        } else if let typeArray = type as? [String] {
            isRecipe = typeArray.contains("Recipe")
        } else {
            isRecipe = false
        }

        guard isRecipe else { return nil }

        let title = dict["name"] as? String ?? ""
        let ingredients = (dict["recipeIngredient"] as? [String]) ?? []

        var directions: [String] = []
        if let instructions = dict["recipeInstructions"] {
            if let steps = instructions as? [String] {
                directions = steps
            } else if let steps = instructions as? [[String: Any]] {
                directions = steps.compactMap { step in
                    if let text = step["text"] as? String {
                        return text
                    }
                    if let items = step["itemListElement"] as? [[String: Any]] {
                        return items.compactMap { $0["text"] as? String }.joined(separator: "\n")
                    }
                    return step["name"] as? String
                }
            } else if let instructionString = instructions as? String {
                directions = instructionString
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        let prepTime = parseISO8601Duration(dict["prepTime"] as? String)
        let cookTime = parseISO8601Duration(dict["cookTime"] as? String)

        var imageURL: String?
        if let image = dict["image"] {
            if let urlString = image as? String {
                imageURL = urlString
            } else if let imageDict = image as? [String: Any] {
                imageURL = imageDict["url"] as? String
            } else if let imageArray = image as? [Any] {
                if let first = imageArray.first as? String {
                    imageURL = first
                } else if let first = imageArray.first as? [String: Any] {
                    imageURL = first["url"] as? String
                }
            }
        }

        let notes = dict["description"] as? String ?? ""

        return ParsedRecipe(
            title: stripHTML(title),
            ingredients: ingredients.map { stripHTML($0) },
            directions: directions.map { stripHTML($0) },
            sourceURL: sourceURL,
            imageURL: imageURL,
            prepDuration: prepTime,
            cookDuration: cookTime,
            notes: stripHTML(notes)
        )
    }

    // MARK: - ISO 8601 Duration Parsing

    private static func parseISO8601Duration(_ duration: String?) -> TimeInterval {
        guard let duration = duration else { return 0 }

        var totalSeconds: TimeInterval = 0
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }

        let range = NSRange(duration.startIndex..., in: duration)
        guard let match = regex.firstMatch(in: duration, range: range) else { return 0 }

        if let hoursRange = Range(match.range(at: 1), in: duration),
           let hours = Double(duration[hoursRange]) {
            totalSeconds += hours * 3600
        }
        if let minutesRange = Range(match.range(at: 2), in: duration),
           let minutes = Double(duration[minutesRange]) {
            totalSeconds += minutes * 60
        }
        if let secondsRange = Range(match.range(at: 3), in: duration),
           let seconds = Double(duration[secondsRange]) {
            totalSeconds += seconds
        }

        return totalSeconds
    }

    // MARK: - HTML Helpers

    private static func stripHTML(_ string: String) -> String {
        var result = string
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode numeric HTML entities (decimal &#8217; and hex &#x2019;)
        if let regex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(result[hexRange], radix: 16),
                   let scalar = Unicode.Scalar(codePoint) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let decRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(result[decRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }

        // Decode common named entities
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&ndash;", with: "\u{2013}")
            .replacingOccurrences(of: "&mdash;", with: "\u{2014}")
            .replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
            .replacingOccurrences(of: "&rsquo;", with: "\u{2019}")
            .replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
            .replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
            .replacingOccurrences(of: "&bull;", with: "\u{2022}")
            .replacingOccurrences(of: "&deg;", with: "\u{00B0}")
            .replacingOccurrences(of: "&frac12;", with: "\u{00BD}")
            .replacingOccurrences(of: "&frac13;", with: "\u{2153}")
            .replacingOccurrences(of: "&frac14;", with: "\u{00BC}")
            .replacingOccurrences(of: "&frac34;", with: "\u{00BE}")
            // Replace non-breaking spaces with regular spaces (prevents SwiftUI wrapping issues)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    // MARK: - Meta Tag Fallback

    private static func parseMetaTags(html: String, sourceURL: String) -> ParsedRecipe? {
        var title = ""

        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            title = ogTitle
        } else if let titleRange = html.range(of: #"<title[^>]*>(.*?)</title>"#, options: .regularExpression) {
            title = stripHTML(String(html[titleRange]))
        }

        var imageURL: String?
        if let ogImage = extractMetaContent(html: html, property: "og:image") {
            imageURL = ogImage
        }

        guard !title.isEmpty else { return nil }

        return ParsedRecipe(
            title: stripHTML(title),
            ingredients: [],
            directions: [],
            sourceURL: sourceURL,
            imageURL: imageURL,
            prepDuration: 0,
            cookDuration: 0,
            notes: ""
        )
    }

    private static func extractMetaContent(html: String, property: String) -> String? {
        // Try: <meta property="X" content="Y">
        let pattern1 = #"<meta[^>]*(?:property|name)\s*=\s*["']\#(property)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#
        if let regex = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }

        // Try reversed order: <meta content="Y" property="X">
        let pattern2 = #"<meta[^>]*content\s*=\s*["']([^"']*)["'][^>]*(?:property|name)\s*=\s*["']\#(property)["'][^>]*>"#
        if let regex = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }

        return nil
    }

    // MARK: - Image Download

    static func downloadImage(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
}
