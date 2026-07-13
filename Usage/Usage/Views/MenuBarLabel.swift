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
                Text(
                    "\(Int(snapshot.weeklyUsage.remainingPercent.rounded()))% · "
                        + snapshot.weeklyUsage.resetAt.formatted(.dateTime.weekday(.abbreviated)),
                )
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                Text(self.store.isRefreshing ? "Loading" : "Unavailable")
            }
        }
    }
}
