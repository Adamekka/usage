//
//  ClaudeUsageResponse.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ClaudeUsageResponse: Decodable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?
}
