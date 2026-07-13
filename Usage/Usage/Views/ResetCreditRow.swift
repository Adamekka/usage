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
        HStack(spacing: 10) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(self.isUrgent ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reset \(self.number)")
                    .fontWeight(.medium)

                if let expiresAt = credit.expiresAt {
                    Text(expiresAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(self.isUrgent ? .orange : .secondary)
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

    private var isUrgent: Bool {
        guard let expiresAt = credit.expiresAt else {
            return false
        }

        return expiresAt.timeIntervalSinceNow <= 7 * 24 * 60 * 60
    }
}
