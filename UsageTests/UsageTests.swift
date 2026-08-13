//
//  UsageTests.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation
import Testing
@testable import Usage

@MainActor
struct UsageTests {
    @Test
    func `Codex auth decodes explicit token keys`() throws {
        let data: Data = .init(
            #"{"tokens":{"access_token":"access","account_id":"account"}}"#.utf8,
        )
        let auth: CodexAuth = try JSONDecoder().decode(CodexAuth.self, from: data)

        #expect(auth.tokens.accessToken == "access")
        #expect(auth.tokens.accountID == "account")
    }

    @Test
    func `reset endpoint authorization failures mean no credits`() throws {
        #expect(try OpenAIClient.resetCreditsAreUnavailableForTesting(statusCode: 401))
        #expect(try OpenAIClient.resetCreditsAreUnavailableForTesting(statusCode: 403))
        #expect(try !OpenAIClient.resetCreditsAreUnavailableForTesting(statusCode: 200))
    }

    @Test
    func `usage endpoint authorization failure requires login`() {
        #expect(throws: OpenAIError.needsCodexLogin) {
            try OpenAIClient.validateUsageResponseForTesting(statusCode: 403)
        }
    }

    @Test
    func `unexpected reset endpoint failure remains explicit`() {
        #expect(throws: OpenAIError.requestFailed(500)) {
            try OpenAIClient.resetCreditsAreUnavailableForTesting(statusCode: 500)
        }
    }

    @Test
    func `whole day pacing targets`() {
        let resetAt: Date = .init(timeIntervalSince1970: 7 * 24 * 60 * 60)
        let usage: WeeklyUsage = .init(resetAt: resetAt, usedPercent: 35)

        #expect(usage.currentDay(at: Date(timeIntervalSince1970: 1)) == 1)
        #expect(usage.currentDay(at: Date(timeIntervalSince1970: 24 * 60 * 60)) == 2)
        #expect(usage.targetUsedPercent(at: Date(timeIntervalSince1970: 24 * 60 * 60)) == 100.0 / 7 * 2)
    }

    @Test
    func `usage remaining cannot be negative`() {
        #expect(WeeklyUsage(resetAt: .now, usedPercent: 87).remainingPercent == 13)
        #expect(WeeklyUsage(resetAt: .now, usedPercent: 105).remainingPercent == 0)
    }
}
