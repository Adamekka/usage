//
//  OpenAIError.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

enum OpenAIError: LocalizedError {
    case invalidCodexLogin
    case invalidResponse
    case needsCodexLogin
    case requestFailed(Int)
    case weeklyLimitUnavailable

    var errorDescription: String? {
        switch self {
            case .invalidCodexLogin:
                "Could not read the Codex login. Run `codex login` again."

            case .invalidResponse:
                "OpenAI returned an invalid response."

            case .needsCodexLogin:
                "Run `codex login` to reconnect OpenAI."

            case let .requestFailed(statusCode):
                "OpenAI returned HTTP \(statusCode)."

            case .weeklyLimitUnavailable:
                "OpenAI did not return a weekly limit."
        }
    }
}
