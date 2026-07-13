//
//  RateLimitWindow.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct RateLimitWindow: Decodable {
    let limitWindowSeconds: Int
    let resetAt: Date
    let usedPercent: Double
}
