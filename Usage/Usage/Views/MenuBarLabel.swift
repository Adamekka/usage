//
//  MenuBarLabel.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct MenuBarLabel: View {
    let store: UsageStore

    var body: some View {
        if let snapshot = store.snapshot {
            HStack(spacing: 4) {
                let weeklyText: String = "\(Int(snapshot.weeklyUsage.remainingPercent.rounded()))% · "
                    + snapshot.weeklyUsage.resetAt.formatted(.dateTime.weekday(.abbreviated))

                if let fiveHourUsage = snapshot.fiveHourUsage {
                    Text(
                        "\(Int(fiveHourUsage.remainingPercent.rounded()))% · "
                            + fiveHourUsage.resetAt.formatted(.dateTime.hour().minute())
                            + " | "
                            + weeklyText,
                    )
                } else {
                    Text(weeklyText)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                Text(self.store.isRefreshing ? "Loading" : "Unavailable")
            }
        }
    }
}
