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
        #expect(
            usage.targetUsedPercent(at: Date(timeIntervalSince1970: 24 * 60 * 60), pacing: .linear) == 100.0 / 7 * 2,
        )
    }

    @Test
    func `logarithmic daily budgets match the agreed curve`() {
        let resetAt: Date = .init(timeIntervalSince1970: WeeklyUsage.duration)
        let usage: WeeklyUsage = .init(resetAt: resetAt, usedPercent: 35)
        let dailyBudgets: [Double] = [33.3, 19.5, 13.8, 10.7, 8.8, 7.4, 6.4]
        var previousTarget: Double = 0

        for (index, budget) in dailyBudgets.enumerated() {
            let date: Date = .init(timeIntervalSince1970: Double(index) * 24 * 60 * 60)
            let target: Double = usage.targetUsedPercent(at: date, pacing: .logarithmic)

            #expect(abs(target - previousTarget - budget) < 0.05)
            previousTarget = target
        }

        #expect(previousTarget == 100)
    }

    @Test(arguments: WeeklyUsage.Pacing.allCases)
    func `pacing targets keep whole day and reset boundaries`(pacing: WeeklyUsage.Pacing) {
        let resetAt: Date = .init(timeIntervalSince1970: WeeklyUsage.duration)
        let usage: WeeklyUsage = .init(resetAt: resetAt, usedPercent: 35)
        let start: Date = .init(timeIntervalSince1970: 0)
        let firstTarget: Double = usage.targetUsedPercent(at: start, pacing: pacing)

        #expect(usage.targetUsedPercent(at: start.addingTimeInterval(-1), pacing: pacing) == firstTarget)
        #expect(usage.targetUsedPercent(at: start.addingTimeInterval(24 * 60 * 60 - 1), pacing: pacing) == firstTarget)
        #expect(usage.targetUsedPercent(at: resetAt.addingTimeInterval(-1), pacing: pacing) == 100)
        #expect(usage.targetUsedPercent(at: resetAt, pacing: pacing) == 100)
        #expect(usage.targetUsedPercent(at: resetAt.addingTimeInterval(1), pacing: pacing) == 100)
    }

    @Test
    func `usage remaining cannot be negative`() {
        #expect(WeeklyUsage(resetAt: .now, usedPercent: 87).remainingPercent == 13)
        #expect(WeeklyUsage(resetAt: .now, usedPercent: 105).remainingPercent == 0)
        #expect(FiveHourUsage(resetAt: .now, usedPercent: 42).remainingPercent == 58)
        #expect(FiveHourUsage(resetAt: .now, usedPercent: 110).remainingPercent == 0)
    }

    @Test
    func `rate limit windows are identified by duration in either slot`() throws {
        let fiveHourWindow: RateLimitWindow = .init(
            limitWindowSeconds: Int(FiveHourUsage.duration),
            resetAt: Date(timeIntervalSince1970: 5 * 60 * 60),
            usedPercent: 18,
        )
        let weeklyWindow: RateLimitWindow = .init(
            limitWindowSeconds: Int(WeeklyUsage.duration),
            resetAt: Date(timeIntervalSince1970: 7 * 24 * 60 * 60),
            usedPercent: 36,
        )

        let fiveHourFromSecondary: RateLimitWindow = try #require(
            OpenAIClient.rateLimitWindowForTesting(
                duration: FiveHourUsage.duration,
                rateLimit: RateLimit(primaryWindow: weeklyWindow, secondaryWindow: fiveHourWindow),
            ),
        )
        let fiveHourFromPrimary: RateLimitWindow = try #require(
            OpenAIClient.rateLimitWindowForTesting(
                duration: FiveHourUsage.duration,
                rateLimit: RateLimit(primaryWindow: fiveHourWindow, secondaryWindow: weeklyWindow),
            ),
        )
        let weeklyFromSecondary: RateLimitWindow = try #require(
            OpenAIClient.rateLimitWindowForTesting(
                duration: WeeklyUsage.duration,
                rateLimit: RateLimit(primaryWindow: fiveHourWindow, secondaryWindow: weeklyWindow),
            ),
        )

        #expect(fiveHourFromSecondary.usedPercent == 18)
        #expect(fiveHourFromPrimary.usedPercent == 18)
        #expect(weeklyFromSecondary.usedPercent == 36)
        #expect(
            OpenAIClient.rateLimitWindowForTesting(
                duration: FiveHourUsage.duration,
                rateLimit: RateLimit(primaryWindow: weeklyWindow, secondaryWindow: nil),
            ) == nil,
        )
    }
}
