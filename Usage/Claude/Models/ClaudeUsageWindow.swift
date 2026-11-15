//
//  ClaudeUsageWindow.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ClaudeUsageWindow: Decodable {
    // Claude omits the reset time while a window has not started yet.
    let resetsAt: Date?
    let utilization: Double
}
