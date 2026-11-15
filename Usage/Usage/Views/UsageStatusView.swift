//
//  UsageStatusView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct UsageStatusView<Snapshot, Content: View>: View {
    let errorMessage: String?
    let loadingText: String
    let signInHint: String
    let snapshot: Snapshot?
    let store: UsageStore
    @ContentBuilder let content: (Snapshot) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot {
                self.content(snapshot)
            } else if self.store.isRefreshing {
                HStack {
                    ProgressView()
                    Text(self.loadingText)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.title2)

                    Text("Usage unavailable")
                        .font(.headline)

                    Text(self.errorMessage ?? self.signInHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }

            if let errorMessage, self.snapshot != nil {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            Task {
                await self.store.refresh()
            }
        }
    }
}
