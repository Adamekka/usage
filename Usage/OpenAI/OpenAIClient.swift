//
//  OpenAIClient.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct OpenAIClient {
    private enum Endpoint {
        case resetCredits
        case usage
    }

    private enum ResponseDisposition {
        case noResetCredits
        case success
    }

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

        func request(_ url: URL) async throws -> (Data, HTTPURLResponse) {
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

            return (data, response)
        }

        let usageURL: URL = .init(string: "https://chatgpt.com/backend-api/wham/usage")!
        let resetsURL: URL = .init(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

        async let pendingUsageResult: (Data, HTTPURLResponse) = request(usageURL)
        async let pendingResetsResult: (Data, HTTPURLResponse) = request(resetsURL)

        let usageDecoder: JSONDecoder = .init()
        usageDecoder.dateDecodingStrategy = .secondsSince1970
        usageDecoder.keyDecodingStrategy = .convertFromSnakeCase

        let resetsDecoder: JSONDecoder = .init()
        resetsDecoder.dateDecodingStrategy = .iso8601
        resetsDecoder.keyDecodingStrategy = .convertFromSnakeCase

        let usageResult: (Data, HTTPURLResponse) = try await pendingUsageResult
        let usageData: Data = usageResult.0
        let usageResponse: HTTPURLResponse = usageResult.1

        _ = try Self.responseDisposition(statusCode: usageResponse.statusCode, endpoint: .usage)

        let usage: UsageResponse = try usageDecoder.decode(UsageResponse.self, from: usageData)
        let resetsResult: (Data, HTTPURLResponse) = try await pendingResetsResult
        let resetsData: Data = resetsResult.0
        let resetsResponse: HTTPURLResponse = resetsResult.1
        let resets: ResetCreditsResponse = switch try Self.responseDisposition(
            statusCode: resetsResponse.statusCode,
            endpoint: .resetCredits,
        ) {
            case .noResetCredits:
                .init(availableCount: 0, credits: [])

            case .success:
                try resetsDecoder.decode(ResetCreditsResponse.self, from: resetsData)
        }

        let fiveHourWindow: RateLimitWindow? = Self.rateLimitWindow(
            duration: FiveHourUsage.duration,
            rateLimit: usage.rateLimit,
        )
        let weeklyWindow: RateLimitWindow? = Self.rateLimitWindow(
            duration: WeeklyUsage.duration,
            rateLimit: usage.rateLimit,
        )

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
            fiveHourUsage: fiveHourWindow.map {
                FiveHourUsage(resetAt: $0.resetAt, usedPercent: $0.usedPercent)
            },
            resetCredits: availableResets,
            weeklyUsage: WeeklyUsage(
                resetAt: weeklyWindow.resetAt,
                usedPercent: weeklyWindow.usedPercent,
            ),
        )
    }

    private static func rateLimitWindow(duration: TimeInterval, rateLimit: RateLimit?) -> RateLimitWindow? {
        [rateLimit?.primaryWindow, rateLimit?.secondaryWindow]
            .compactMap(\.self)
            .first { $0.limitWindowSeconds == Int(duration) }
    }

    private static func responseDisposition(statusCode: Int, endpoint: Endpoint) throws -> ResponseDisposition {
        if statusCode == 401 || statusCode == 403 {
            switch endpoint {
                case .resetCredits:
                    // A valid usage response proves the login works; this endpoint uses authorization failures for no
                    // credits.
                    return .noResetCredits

                case .usage:
                    throw OpenAIError.needsCodexLogin
            }
        }

        guard (200 ..< 300).contains(statusCode) else {
            throw OpenAIError.requestFailed(statusCode)
        }

        return .success
    }

    #if DEBUG
        static func resetCreditsAreUnavailableForTesting(statusCode: Int) throws -> Bool {
            try self.responseDisposition(statusCode: statusCode, endpoint: .resetCredits) == .noResetCredits
        }

        static func validateUsageResponseForTesting(statusCode: Int) throws {
            _ = try self.responseDisposition(statusCode: statusCode, endpoint: .usage)
        }

        static func rateLimitWindowForTesting(duration: TimeInterval, rateLimit: RateLimit?) -> RateLimitWindow? {
            self.rateLimitWindow(duration: duration, rateLimit: rateLimit)
        }
    #endif
}
