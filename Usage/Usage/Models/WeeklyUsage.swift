//
//  WeeklyUsage.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct WeeklyUsage {
    static let duration: TimeInterval = 7 * 24 * 60 * 60

    let resetAt: Date
    let usedPercent: Double

    var remainingPercent: Double {
        max(0, 100 - self.usedPercent)
    }

    func currentDay(at date: Date) -> Int {
        let elapsed: TimeInterval = date.timeIntervalSince(self.resetAt.addingTimeInterval(-Self.duration))
        return min(7, max(1, Int(elapsed / (24 * 60 * 60)) + 1))
    }

    func targetUsedPercent(at date: Date) -> Double {
        100 / 7 * Double(self.currentDay(at: date))
    }
}
