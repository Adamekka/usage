//
//  Pacing.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

enum Pacing: String, CaseIterable {
    case linear
    case logarithmic

    func targetUsedPercent(resetAt: Date, duration: TimeInterval, at date: Date) -> Double {
        let elapsed: TimeInterval = date.timeIntervalSince(resetAt.addingTimeInterval(-duration))
        // A continuous fraction so the target advances smoothly instead of jumping at fixed boundaries.
        let fraction: Double = min(1, max(0, elapsed / duration))

        switch self {
            case .linear:
                return 100 * fraction

            case .logarithmic:
                // Scale every window to seven units so it follows the same curve as the weekly window's seven days.
                // Shift the logarithm to start at zero and normalize it so the end of the window reaches 100%.
                return 100 * (log1p(7 * fraction) / log(8))
        }
    }
}
