//
//  ClaudeCredentials.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
        let expiresAt: Date
    }

    let claudeAiOauth: OAuth
}
