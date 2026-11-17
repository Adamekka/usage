//
//  ClaudeClient.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation
import Security

struct ClaudeClient {
    func fetchSnapshot() async throws -> ClaudeSnapshot {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            throw ClaudeError.missingClaudeLogin
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw ClaudeError.invalidClaudeLogin
        }

        let credentials: ClaudeCredentials

        do {
            let decoder: JSONDecoder = .init()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            credentials = try decoder.decode(ClaudeCredentials.self, from: data)
        } catch {
            throw ClaudeError.invalidClaudeLogin
        }

        guard !credentials.claudeAiOauth.accessToken.isEmpty else {
            throw ClaudeError.invalidClaudeLogin
        }

        // Claude Code owns token refresh; an expired token needs Claude Code to run again.
        guard credentials.claudeAiOauth.expiresAt > .now else {
            throw ClaudeError.needsClaudeLogin
        }

        var request: URLRequest = .init(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(credentials.claudeAiOauth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Usage/macOS", forHTTPHeaderField: "User-Agent")

        let result: (Data, URLResponse) = try await URLSession.shared.data(for: request)

        guard let response = result.1 as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        try Self.validate(statusCode: response.statusCode)

        return try Self.snapshot(from: result.0)
    }

    private static func validate(statusCode: Int) throws {
        if statusCode == 401 || statusCode == 403 {
            throw ClaudeError.needsClaudeLogin
        }

        if statusCode == 429 {
            throw ClaudeError.rateLimited
        }

        guard (200 ..< 300).contains(statusCode) else {
            throw ClaudeError.requestFailed(statusCode)
        }
    }

    private static func snapshot(from data: Data) throws -> ClaudeSnapshot {
        let decoder: JSONDecoder = .init()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container: any SingleValueDecodingContainer = try decoder.singleValueContainer()
            let string: String = try container.decode(String.self)

            do {
                // Claude sends microsecond timestamps, which the built-in ISO 8601 strategy rejects.
                return try Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
            } catch {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
            }
        }

        let usage: ClaudeUsageResponse

        do {
            usage = try decoder.decode(ClaudeUsageResponse.self, from: data)
        } catch {
            throw ClaudeError.invalidResponse
        }

        guard let sevenDay = usage.sevenDay, let weeklyResetAt = sevenDay.resetsAt else {
            throw ClaudeError.weeklyLimitUnavailable
        }

        return ClaudeSnapshot(
            fiveHourUsage: usage.fiveHour.flatMap { window in
                window.resetsAt.map { FiveHourUsage(resetAt: $0, usedPercent: window.utilization) }
            },
            weeklyUsage: WeeklyUsage(resetAt: weeklyResetAt, usedPercent: sevenDay.utilization),
        )
    }

    #if DEBUG
        static func validateForTesting(statusCode: Int) throws {
            try self.validate(statusCode: statusCode)
        }

        static func snapshotForTesting(from data: Data) throws -> ClaudeSnapshot {
            try self.snapshot(from: data)
        }
    #endif
}
