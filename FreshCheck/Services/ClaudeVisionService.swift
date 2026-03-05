// FreshCheck/Services/ClaudeVisionService.swift
import Foundation
import UIKit

final class ClaudeVisionService {

    // Local dev: set FRESHCHECK_PROXY_URL in your Xcode Scheme environment variables.
    // Example: https://freshcheck-proxy-production.up.railway.app
    static var proxyURLString: String {
        normalizedValue(ProcessInfo.processInfo.environment["FRESHCHECK_PROXY_URL"] ?? "")
    }

    static var proxyToken: String {
        normalizedValue(ProcessInfo.processInfo.environment["FRESHCHECK_PROXY_TOKEN"] ?? "")
    }

    private static var prompt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return """
        You are analyzing a photo of food that will be stored in a fridge.

        1. Identify the food item(s) visible in the photo.
        2. If a printed expiry/best-before date is visible on packaging, extract it.
        3. If no printed date is visible, estimate shelf life in the fridge based on food safety standards.

        Today's date is \(today).

        Respond ONLY with JSON in this exact format:
        {
          "name": "Broccoli",
          "category": "produce",
          "expiryDate": "2026-03-05",
          "confidenceSource": "shelfLife",
          "shelfLifeDays": 5
        }

        category must be one of: produce | meat | dairy | packaged | other
        confidenceSource must be one of: ocr | shelfLife
        shelfLifeDays is null when confidenceSource is ocr
        """
    }

    // MARK: - Public API

    static func analyze(image: UIImage) async throws -> FoodAnalysis {
        let resized = resizeImage(image, maxDimension: 1024)
        guard let imageData = resized.jpegData(compressionQuality     : 0.8) else {
            throw AnalysisError.imageEncodingFailed
        }
        let base64 = imageData.base64EncodedString()
        let body = buildRequestBody(base64Image: base64)
        let endpoint = try resolvedEndpoint()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if !proxyToken.isEmpty {
            request.setValue(proxyToken, forHTTPHeaderField: "x-client-token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        // Retry up to 3 times on transient server errors (502, 503, 529)
        var lastError: Error = AnalysisError.apiError
        for attempt in 1...3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                    print("❌ Proxy API error (attempt \(attempt)): \(statusCode) — \(responseBody)")
                    if statusCode == 401 {
                        throw AnalysisError.invalidApiKey(
                            "Proxy authentication failed. Check FRESHCHECK_PROXY_TOKEN. Server: \(responseBody)"
                        )
                    }
                    if [502, 503, 529].contains(statusCode) && attempt < 3 {
                        try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                        continue
                    }
                    throw AnalysisError.apiError
                }
                print("✅ Proxy raw response: \(String(data: data, encoding: .utf8) ?? "unreadable")")

                var analysis = try parseResponse(data)

                // Cap implausible shelf life for produce and meat
                if let days = analysis.shelfLifeDays {
                    let capped = capShelfLifeDays(days, for: analysis.category)
                    if capped != days {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        analysis = FoodAnalysis(
                            name: analysis.name,
                            category: analysis.category,
                            expiryDate: Calendar.current.date(
                                byAdding: .day, value: capped, to: Date()
                            ).map { dateFormatter.string(from: $0) } ?? analysis.expiryDate,
                            confidenceSource: analysis.confidenceSource,
                            shelfLifeDays: capped
                        )
                    }
                }
                return analysis

            } catch let error as AnalysisError {
                throw error  // don't retry on our own errors
            } catch {
                lastError = error
                print("❌ Network error (attempt \(attempt)): \(error)")
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError
    }

    // MARK: - Helpers (internal for testability)

    static func parseResponse(_ data: Data) throws -> FoodAnalysis {
        // Claude wraps response in messages structure — extract text content
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String {
            let cleaned = extractJSONObjectText(from: text)
            guard let jsonData = cleaned.data(using: .utf8) else {
                throw AnalysisError.invalidResponse("Claude response text could not be converted to UTF-8 JSON.")
            }
            return try JSONDecoder().decode(FoodAnalysis.self, from: jsonData)
        }
        // Fallback: try to decode directly (for unit tests with raw JSON)
        return try JSONDecoder().decode(FoodAnalysis.self, from: data)
    }

    static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    static func capShelfLifeDays(_ days: Int, for category: FoodCategory) -> Int {
        switch category {
        case .produce, .meat: return min(days, 30)
        default:              return days
        }
    }

    // MARK: - Private

    private static func buildRequestBody(base64Image: String) -> [String: Any] {
        ["imageBase64": base64Image, "prompt": prompt, "language": L10n.aiLanguageCode]
    }

    private static func normalizedValue(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func resolvedEndpoint() throws -> URL {
        guard !proxyURLString.isEmpty else {
            throw AnalysisError.invalidConfiguration(
                "Missing FRESHCHECK_PROXY_URL. Set it in Xcode: Product > Scheme > Edit Scheme > Run > Environment Variables."
            )
        }
        guard let base = URL(string: proxyURLString) else {
            throw AnalysisError.invalidConfiguration("Invalid FRESHCHECK_PROXY_URL: \(proxyURLString)")
        }
        return base.appending(path: "v1/food/analyze")
    }

    // Claude sometimes wraps JSON in markdown code fences. Extract the JSON object text.
    private static func extractJSONObjectText(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: .newlines)
            if lines.count >= 2 {
                let withoutFirstFence = Array(lines.dropFirst())
                let withoutLastFence: [String]
                if withoutFirstFence.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
                    withoutLastFence = Array(withoutFirstFence.dropLast())
                } else {
                    withoutLastFence = withoutFirstFence
                }
                text = withoutLastFence.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last {
            return String(text[first...last])
        }
        return text
    }

    enum AnalysisError: Error {
        case imageEncodingFailed
        case invalidConfiguration(String)
        case invalidApiKey(String)
        case invalidResponse(String)
        case apiError
        case unrecognizedFood
    }
}
