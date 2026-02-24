import Foundation

struct RecipeURLImporter {

    typealias ParsedRecipe = RecipeParserCore.ParsedRecipe

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

        if let recipe = RecipeParserCore.parseRecipe(html: html, sourceURL: urlString) {
            return recipe
        }

        throw ImportError.parsingFailed
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
