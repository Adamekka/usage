//
//  OpenAIError.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

enum OpenAIError: LocalizedError, Equatable {
    case invalidCodexLogin
    case invalidResponse
    case missingCodexLogin
    case needsCodexLogin
    case requestFailed(Int)
    case weeklyLimitUnavailable

    /// Whether the failure means there is no usable Codex access, such as no login or no subscription limit, rather
    /// than a temporary problem that the next refresh may fix.
    var isAccessLost: Bool {
        switch self {
            case .invalidCodexLogin, .missingCodexLogin, .needsCodexLogin, .weeklyLimitUnavailable:
                true

            case .invalidResponse, .requestFailed:
                false
        }
    }

    var errorDescription: String? {
        switch self {
            case .invalidCodexLogin:
                "Could not read the Codex login. Run `codex login` again."

            case .invalidResponse:
                "OpenAI returned an invalid response."

            case .missingCodexLogin:
                "Run `codex login` to connect Codex."

            case .needsCodexLogin:
                "Run `codex login` to reconnect OpenAI."

            case let .requestFailed(statusCode):
                "OpenAI returned HTTP \(statusCode)."

            case .weeklyLimitUnavailable:
                "OpenAI did not return a weekly limit."
        }
    }
}
