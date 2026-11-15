//
//  OpenAIUsageView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct OpenAIUsageView: View {
    let store: UsageStore

    var body: some View {
        UsageStatusView(
            errorMessage: self.store.openAIErrorMessage,
            loadingText: "Loading Codex usage…",
            signInHint: "Run `codex login`, then refresh.",
            snapshot: self.store.openAISnapshot,
            store: self.store,
        ) { snapshot in
            UsageLimitsView(fiveHourUsage: snapshot.fiveHourUsage, weeklyUsage: snapshot.weeklyUsage)

            if snapshot.availableResetCount > 0 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Banked resets")
                            .font(.headline)

                        Spacer()

                        Text("\(snapshot.availableResetCount) available")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(snapshot.resetCredits.enumerated()), id: \.element.id) { index, credit in
                        ResetCreditRow(credit: credit, number: index + 1)
                    }
                }
            }
        }
    }
}
