//
//  OpenAIClient.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct OpenAIClient {
    func fetchSnapshot() async throws -> OpenAISnapshot {
        let authURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appending(path: ".codex/auth.json")

        let auth: CodexAuth

        do {
            let decoder: JSONDecoder = .init()
            auth = try decoder.decode(CodexAuth.self, from: Data(contentsOf: authURL))
        } catch {
            throw OpenAIError.invalidCodexLogin
        }

        guard !auth.tokens.accessToken.isEmpty else {
            throw OpenAIError.invalidCodexLogin
        }

        func request(_ url: URL) async throws -> Data {
            var request: URLRequest = .init(url: url)
            request.setValue("Bearer \(auth.tokens.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("Usage/macOS", forHTTPHeaderField: "User-Agent")

            if let accountID = auth.tokens.accountID {
                request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
            }

            let result: (Data, URLResponse) = try await URLSession.shared.data(for: request)
            let data: Data = result.0
            let response: URLResponse = result.1

            guard let response = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }

            if response.statusCode == 401 || response.statusCode == 403 {
                throw OpenAIError.needsCodexLogin
            }

            guard (200 ..< 300).contains(response.statusCode) else {
                throw OpenAIError.requestFailed(response.statusCode)
            }

            return data
        }

        let usageURL: URL = .init(string: "https://chatgpt.com/backend-api/wham/usage")!
        let resetsURL: URL = .init(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

        async let usageData: Data = request(usageURL)
        async let resetsData: Data = request(resetsURL)

        let usageDecoder: JSONDecoder = .init()
        usageDecoder.dateDecodingStrategy = .secondsSince1970
        usageDecoder.keyDecodingStrategy = .convertFromSnakeCase

        let resetsDecoder: JSONDecoder = .init()
        resetsDecoder.dateDecodingStrategy = .iso8601
        resetsDecoder.keyDecodingStrategy = .convertFromSnakeCase

        let usage: UsageResponse = try await usageDecoder.decode(UsageResponse.self, from: usageData)
        let resets: ResetCreditsResponse = try await resetsDecoder.decode(ResetCreditsResponse.self, from: resetsData)
        let weeklyWindow: RateLimitWindow? = [usage.rateLimit?.primaryWindow, usage.rateLimit?.secondaryWindow]
            .compactMap(\.self)
            .first { $0.limitWindowSeconds == Int(WeeklyUsage.duration) }

        guard let weeklyWindow else {
            throw OpenAIError.weeklyLimitUnavailable
        }

        let availableResets: [ResetCredit] = resets.credits
            .filter { $0.status == "available" }
            .sorted {
                switch ($0.expiresAt, $1.expiresAt) {
                    case let (lhs?, rhs?):
                        lhs < rhs

                    case (nil, _?):
                        false

                    case (_?, nil):
                        true

                    case (nil, nil):
                        false
                }
            }

        return OpenAISnapshot(
            availableResetCount: resets.availableCount,
            resetCredits: availableResets,
            weeklyUsage: WeeklyUsage(
                resetAt: weeklyWindow.resetAt,
                usedPercent: weeklyWindow.usedPercent,
            ),
        )
    }
}
