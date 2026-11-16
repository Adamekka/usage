//
//  ResetCreditRow.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct ResetCreditRow: View {
    let credit: ResetCredit
    let number: Int

    var body: some View {
        // The relative expiration and urgency depend on the current time, which SwiftUI does not observe, so redraw
        // periodically instead of only when the credit changes.
        TimelineView(.periodic(from: .now, by: 15 * 60)) { context in
            let isUrgent: Bool = self.credit.expiresAt.map { $0.timeIntervalSince(context.date) <= 7 * 24 * 60 * 60 }
                ?? false

            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isUrgent ? .orange : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset \(self.number)")
                        .fontWeight(.medium)

                    if let expiresAt = credit.expiresAt {
                        Text(expiresAt, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(isUrgent ? .orange : .secondary)
                    } else {
                        Text("No expiration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let expiresAt = credit.expiresAt {
                    Text(expiresAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                        .font(.callout.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
