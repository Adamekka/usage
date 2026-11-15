//
//  ClaudeError.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

enum ClaudeError: LocalizedError, Equatable {
    case invalidClaudeLogin
    case invalidResponse
    case needsClaudeLogin
    case rateLimited
    case requestFailed(Int)
    case weeklyLimitUnavailable

    var errorDescription: String? {
        switch self {
            case .invalidClaudeLogin:
                "Could not read the Claude Code login. Run `claude` and sign in again."

            case .invalidResponse:
                "Claude returned an invalid response."

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
