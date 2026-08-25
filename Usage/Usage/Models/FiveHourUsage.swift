//
//  FiveHourUsage.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct FiveHourUsage {
    static let duration: TimeInterval = 5 * 60 * 60

    let resetAt: Date
    let usedPercent: Double

    var remainingPercent: Double {
        max(0, 100 - self.usedPercent)
    }
}
