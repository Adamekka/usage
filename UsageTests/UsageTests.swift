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
    func `pacing targets advance smoothly within a day`() {
        let resetAt: Date = .init(timeIntervalSince1970: 7 * 24 * 60 * 60)
        let usage: WeeklyUsage = .init(resetAt: resetAt, usedPercent: 35)

        #expect(usage.currentDay(at: Date(timeIntervalSince1970: 1)) == 1)
        #expect(usage.currentDay(at: Date(timeIntervalSince1970: 24 * 60 * 60)) == 2)
        #expect(
            abs(
                Pacing.linear.targetUsedPercent(
                    resetAt: resetAt,
                    duration: WeeklyUsage.duration,
                    at: Date(timeIntervalSince1970: 36 * 60 * 60),
                ) - 100.0 / 7 * 1.5,
            ) < 0.000_001,
        )
    }

    @Test
    func `logarithmic daily budgets match the agreed curve`() {
        let resetAt: Date = .init(timeIntervalSince1970: WeeklyUsage.duration)
        let dailyBudgets: [Double] = [33.3, 19.5, 13.8, 10.7, 8.8, 7.4, 6.4]
        var previousTarget: Double = 0

        for (index, budget) in dailyBudgets.enumerated() {
            let date: Date = .init(timeIntervalSince1970: Double(index + 1) * 24 * 60 * 60)
            let target: Double = Pacing.logarithmic.targetUsedPercent(
                resetAt: resetAt,
                duration: WeeklyUsage.duration,
                at: date,
            )

            #expect(abs(target - previousTarget - budget) < 0.05)
            previousTarget = target
        }

        #expect(previousTarget == 100)
    }

    @Test(arguments: Pacing.allCases)
    func `pacing targets clamp to window boundaries`(pacing: Pacing) {
        let resetAt: Date = .init(timeIntervalSince1970: WeeklyUsage.duration)
        let start: Date = .init(timeIntervalSince1970: 0)

        func target(at date: Date) -> Double {
            pacing.targetUsedPercent(resetAt: resetAt, duration: WeeklyUsage.duration, at: date)
        }

        #expect(target(at: start.addingTimeInterval(-1)) == 0)
        #expect(target(at: start) == 0)
        #expect(target(at: start.addingTimeInterval(60)) > 0)
        #expect(target(at: resetAt.addingTimeInterval(-60)) < 100)
        #expect(target(at: resetAt) == 100)
        #expect(target(at: resetAt.addingTimeInterval(1)) == 100)
    }

    @Test(arguments: Pacing.allCases)
    func `five-hour pacing follows the weekly curve over five hours`(pacing: Pacing) {
        let weeklyResetAt: Date = .init(timeIntervalSince1970: WeeklyUsage.duration)
        let fiveHourResetAt: Date = .init(timeIntervalSince1970: FiveHourUsage.duration)

        for fraction in [0, 0.25, 0.5, 1] {
            let weeklyTarget: Double = pacing.targetUsedPercent(
                resetAt: weeklyResetAt,
                duration: WeeklyUsage.duration,
                at: Date(timeIntervalSince1970: WeeklyUsage.duration * fraction),
            )
            let fiveHourTarget: Double = pacing.targetUsedPercent(
                resetAt: fiveHourResetAt,
                duration: FiveHourUsage.duration,
                at: Date(timeIntervalSince1970: FiveHourUsage.duration * fraction),
            )

            #expect(abs(weeklyTarget - fiveHourTarget) < 0.000_001)
        }
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

    @Test
    func `Claude credentials decode the Claude Code keychain item`() throws {
        let data: Data = .init(
            #"{"claudeAiOauth":{"accessToken":"access","refreshToken":"refresh","expiresAt":1794798650224}}"#.utf8,
        )
        let decoder: JSONDecoder = .init()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let credentials: ClaudeCredentials = try decoder.decode(ClaudeCredentials.self, from: data)

        #expect(credentials.claudeAiOauth.accessToken == "access")
        #expect(credentials.claudeAiOauth.expiresAt == Date(timeIntervalSince1970: 1_794_798_650.224))
    }

    @Test
    func `Claude usage decodes microsecond reset timestamps`() throws {
        let data: Data = .init(
            #"""
            {"five_hour":{"utilization":6.0,"resets_at":"2026-11-15T23:50:00.203064+00:00"},
            "seven_day":{"utilization":1.0,"resets_at":"2026-11-17T01:00:00.203089+00:00"},
            "seven_day_opus":null}
            """#.utf8,
        )
        let snapshot: ClaudeSnapshot = try ClaudeClient.snapshotForTesting(from: data)

        #expect(snapshot.fiveHourUsage?.usedPercent == 6)
        #expect(try abs(#require(snapshot.fiveHourUsage?.resetAt.timeIntervalSince1970) - 1_794_786_600.203) < 0.001)
        #expect(snapshot.weeklyUsage.usedPercent == 1)
        #expect(abs(snapshot.weeklyUsage.resetAt.timeIntervalSince1970 - 1_794_877_200.203) < 0.001)
    }

    @Test
    func `Claude five-hour window without a reset is hidden`() throws {
        let data: Data = .init(
            #"""
            {"five_hour":{"utilization":0.0,"resets_at":null},
            "seven_day":{"utilization":12.0,"resets_at":"2026-11-17T01:00:00+00:00"}}
            """#.utf8,
        )

        #expect(try ClaudeClient.snapshotForTesting(from: data).fiveHourUsage == nil)
    }

    @Test
    func `Claude weekly window is required`() {
        let data: Data = .init(#"{"five_hour":null,"seven_day":null}"#.utf8)

        #expect(throws: ClaudeError.weeklyLimitUnavailable) {
            try ClaudeClient.snapshotForTesting(from: data)
        }
    }

    @Test
    func `Claude status codes map to login and request failures`() throws {
        try ClaudeClient.validateForTesting(statusCode: 200)

        #expect(throws: ClaudeError.needsClaudeLogin) {
            try ClaudeClient.validateForTesting(statusCode: 401)
        }
        #expect(throws: ClaudeError.needsClaudeLogin) {
            try ClaudeClient.validateForTesting(statusCode: 403)
        }
        #expect(throws: ClaudeError.rateLimited) {
            try ClaudeClient.validateForTesting(statusCode: 429)
        }
        #expect(throws: ClaudeError.requestFailed(500)) {
            try ClaudeClient.validateForTesting(statusCode: 500)
        }
    }
}
