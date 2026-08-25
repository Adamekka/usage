//
//  OpenAISnapshot.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

struct OpenAISnapshot {
    let availableResetCount: Int
    let fiveHourUsage: FiveHourUsage?
    let resetCredits: [ResetCredit]
    let weeklyUsage: WeeklyUsage
}
