import Foundation

struct RecipeParser {

    typealias ParsedRecipe = RecipeParserCore.ParsedRecipe

    enum ParseError: LocalizedError {
        case invalidURL
        case networkError(String)
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL is not valid."
            case .networkError(let message):
                return "Network error: \(message)"
            case .parsingFailed:
                return "Could not find recipe data on this page."
            }
        }
    }

    static func fetchAndParse(urlString: String) async throws -> ParsedRecipe {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw ParseError.invalidURL
        }

        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw ParseError.networkError(error.localizedDescription)
        }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii) else {
            throw ParseError.parsingFailed
        }

        if let recipe = RecipeParserCore.parseRecipe(html: html, sourceURL: urlString) {
            return recipe
        }

        throw ParseError.parsingFailed
    }

    static func formatDuration(_ seconds: TimeInterval) -> String? {
        RecipeParserCore.formatDuration(seconds)
    }
}
