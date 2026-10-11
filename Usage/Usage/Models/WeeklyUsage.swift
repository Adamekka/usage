//
//  WeeklyUsage.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct WeeklyUsage {
    enum Pacing: String, CaseIterable {
        case linear
        case logarithmic
    }

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

    func targetUsedPercent(at date: Date, pacing: Pacing) -> Double {
        let day: Double = .init(self.currentDay(at: date))

        switch pacing {
            case .linear:
                return 100 / 7 * day

            case .logarithmic:
                // Shift the logarithm to start at zero and normalize it so day 7 reaches 100%.
                return 100 * (log1p(day) / log(8))
        }
    }
}
