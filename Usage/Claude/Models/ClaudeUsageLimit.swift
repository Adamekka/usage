//
//  ClaudeUsageLimit.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ClaudeUsageLimit: Decodable {
    struct Scope: Decodable {
        struct Model: Decodable {
            let displayName: String
        }

        let model: Model?
    }

    /// The server's meter kind, such as `session`, `weekly_all`, or `weekly_scoped`.
    let kind: String
    let percent: Double
    // Claude omits the reset time while a window has not started yet.
    let resetsAt: Date?
    let scope: Scope?
}
