import Foundation

struct RecipeParserCore {

    struct ParsedRecipe: Codable {
        var title: String
        var ingredients: [String]
        var directions: [String]
        var sourceURL: String
        var imageURL: String?
        var prepDuration: TimeInterval
        var cookDuration: TimeInterval
        var notes: String
    }

    // MARK: - Main Entry Point

    static func parseRecipe(html: String, sourceURL: String) -> ParsedRecipe? {
        if var recipe = parseJSONLD(html: html, sourceURL: sourceURL) {
            // Always try HTML fallback and use whichever has more steps
            let htmlDirections = parseDirectionsFromHTML(html: html)
            if htmlDirections.count > recipe.directions.count {
                recipe.directions = htmlDirections
            }
            return recipe
        }

        if let recipe = parseMetaTags(html: html, sourceURL: sourceURL) {
            return recipe
        }

        return nil
    }

    // MARK: - JSON-LD Parsing (Schema.org Recipe)

    static func parseJSONLD(html: String, sourceURL: String) -> ParsedRecipe? {
        let pattern = #"<script[^>]*type\s*=\s*["']?application/ld\+json["']?[^>]*>([\s\S]*?)</script>"#
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
                    if let graph = item["@graph"] as? [[String: Any]] {
                        for graphItem in graph {
                            if let recipe = extractRecipe(from: graphItem, sourceURL: sourceURL) {
                                return recipe
                            }
                        }
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
                for step in steps {
                    let stepType = step["@type"] as? String ?? ""

                    if stepType == "HowToSection" {
                        // HowToSection contains nested HowToStep items — flatten them
                        if let items = step["itemListElement"] as? [[String: Any]] {
                            for item in items {
                                if let text = item["text"] as? String, !text.isEmpty {
                                    directions.append(text)
                                } else if let name = item["name"] as? String, !name.isEmpty {
                                    directions.append(name)
                                }
                            }
                        }
                    } else if let text = step["text"] as? String, !text.isEmpty {
                        directions.append(text)
                    } else if let items = step["itemListElement"] as? [[String: Any]] {
                        for item in items {
                            if let text = item["text"] as? String, !text.isEmpty {
                                directions.append(text)
                            } else if let name = item["name"] as? String, !name.isEmpty {
                                directions.append(name)
                            }
                        }
                    } else if let name = step["name"] as? String, !name.isEmpty {
                        directions.append(name)
                    }
                }
            } else if let instructionString = instructions as? String {
                let withBreaks = instructionString
                    .replacingOccurrences(of: #"</(?:p|li|div|br\s*/?)>"#, with: "\n", options: .regularExpression)
                    .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
                directions = stripHTML(withBreaks)
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

    static func parseISO8601Duration(_ duration: String?) -> TimeInterval {
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

    // MARK: - HTML Directions Fallback

    static func parseDirectionsFromHTML(html: String) -> [String] {
        // Strategy 1: Find <li> elements inside an itemprop="recipeInstructions" container (Microdata)
        let itempropPattern = #"itemprop\s*=\s*["']recipeInstructions["'][^>]*>([\s\S]*?)</(?:ol|ul|div|section)>"#
        if let directions = extractStepsFromHTMLBlock(html: html, pattern: itempropPattern), !directions.isEmpty {
            return directions
        }

        // Strategy 2: Find <p> elements inside step content containers (handles deeply nested structures)
        let stepContentPattern = #"<div[^>]*class\s*=\s*["'][^"']*(?:stepContent|step_content|instruction_content)[^"']*["'][^>]*>([\s\S]*?)</div>"#
        if let regex = try? NSRegularExpression(pattern: stepContentPattern, options: .caseInsensitive) {
            var contentDirections: [String] = []
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let step = stripHTML(String(html[contentRange]))
                    if !step.isEmpty && step.count > 15 {
                        contentDirections.append(step)
                    }
                }
            }
            if !contentDirections.isEmpty {
                return contentDirections
            }
        }

        // Strategy 3: Find <li> elements inside containers with step/instruction/preparation class names
        let classPattern = #"<(?:ol|ul|div|section)[^>]*class\s*=\s*["'][^"']*(?:preparation_step|instruction|step_content|recipe-steps|recipe_steps|steps_list)[^"']*["'][^>]*>([\s\S]*?)</(?:ol|ul|div|section)>"#
        if let directions = extractStepsFromHTMLBlock(html: html, pattern: classPattern), !directions.isEmpty {
            return directions
        }

        // Strategy 4: Find individual <li> or <p> elements with step-related class names
        var directions: [String] = []
        let stepPattern = #"<(?:li|p)[^>]*class\s*=\s*["'][^"']*(?:step_text|step_content|instruction_text|preparation_step)[^"']*["'][^>]*>([\s\S]*?)</(?:li|p)>"#
        if let regex = try? NSRegularExpression(pattern: stepPattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let step = stripHTML(String(html[contentRange]))
                    if !step.isEmpty && step.count > 15 {
                        directions.append(step)
                    }
                }
            }
        }

        return directions
    }

    private static func extractStepsFromHTMLBlock(html: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        var allResults: [String] = []
        for match in matches {
            guard let contentRange = Range(match.range(at: 1), in: html) else { continue }
            let content = String(html[contentRange])

            let itemPattern = #"<(?:li|p)[^>]*>([\s\S]*?)</(?:li|p)>"#
            if let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) {
                let itemRange = NSRange(content.startIndex..., in: content)
                let itemMatches = itemRegex.matches(in: content, range: itemRange)
                for itemMatch in itemMatches {
                    if let itemContentRange = Range(itemMatch.range(at: 1), in: content) {
                        let rawContent = String(content[itemContentRange])
                        if rawContent.range(of: #"<(?:ol|ul)\b"#, options: .regularExpression) != nil {
                            continue
                        }
                        let text = stripHTML(rawContent)
                        if !text.isEmpty && text.count > 15 {
                            allResults.append(text)
                        }
                    }
                }
            }
        }

        return allResults.isEmpty ? nil : allResults
    }

    // MARK: - HTML Helpers

    static func stripHTML(_ string: String) -> String {
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
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    // MARK: - Meta Tag Fallback

    static func parseMetaTags(html: String, sourceURL: String) -> ParsedRecipe? {
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

    static func extractMetaContent(html: String, property: String) -> String? {
        let pattern1 = #"<meta[^>]*(?:property|name)\s*=\s*["']\#(property)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#
        if let regex = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }

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

    // MARK: - Duration Formatting

    static func formatDuration(_ seconds: TimeInterval) -> String? {
        guard seconds > 0 else { return nil }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
