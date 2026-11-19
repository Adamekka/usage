//
//  ClaudeUsageResponse.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ClaudeUsageResponse: Decodable {
    let fiveHour: ClaudeUsageWindow?
    // Model-scoped limits, such as Fable's weekly limit, are only reported in this list, which older responses omit.
    let limits: [ClaudeUsageLimit]?
    let sevenDay: ClaudeUsageWindow?
}
