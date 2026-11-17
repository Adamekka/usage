//
//  ClaudeError.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

enum ClaudeError: LocalizedError, Equatable {
    case invalidClaudeLogin
    case invalidResponse
    case missingClaudeLogin
    case needsClaudeLogin
    case rateLimited
    case requestFailed(Int)
    case weeklyLimitUnavailable

    /// Whether the failure means there is no usable Claude access, such as no login or no subscription limit, rather
    /// than a temporary problem that the next refresh may fix.
    var isAccessLost: Bool {
        switch self {
            case .invalidClaudeLogin, .missingClaudeLogin, .needsClaudeLogin, .weeklyLimitUnavailable:
                true

            case .invalidResponse, .rateLimited, .requestFailed:
                false
        }
    }

    var errorDescription: String? {
        switch self {
            case .invalidClaudeLogin:
                "Could not read the Claude Code login. Run `claude` and sign in again."

            case .invalidResponse:
                "Claude returned an invalid response."

            case .missingClaudeLogin:
                "Run `claude` and sign in to connect Claude."

            case .needsClaudeLogin:
                "Run `claude` to reconnect Claude."

            case .rateLimited:
                "Claude limits how often usage can be checked. Try again in a few minutes."

            case let .requestFailed(statusCode):
                "Claude returned HTTP \(statusCode)."

            case .weeklyLimitUnavailable:
                "Claude did not return a weekly limit."
        }
    }
}
