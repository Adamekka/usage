//
//  OpenAIUsageView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct OpenAIUsageView: View {
    let store: UsageStore

    @AppStorage("weeklyPacing") private var pacing: WeeklyUsage.Pacing = .linear

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = store.snapshot {
                let usage: WeeklyUsage = snapshot.weeklyUsage
                let now: Date = .now
                let target: Double = usage.targetUsedPercent(at: now, pacing: self.pacing)
                let pacing: Double = usage.usedPercent - target

                if let fiveHourUsage = snapshot.fiveHourUsage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Label("5-hour limit", systemImage: "clock")
                                .font(.headline)

                            Spacer()

                            Text("\(Int(fiveHourUsage.remainingPercent.rounded()))% left")
                                .font(.title3.bold().monospacedDigit())
                        }

                        ProgressView(value: fiveHourUsage.remainingPercent, total: 100)
                            .tint(.green)
                            .accessibilityLabel("5-hour limit remaining")

                        Text(
                            "Resets "
                                + fiveHourUsage.resetAt.formatted(
                                    .dateTime.weekday(.wide).hour().minute(),
                                ),
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Weekly limit", systemImage: "calendar.badge.clock")
                            .font(.headline)

                        Spacer()

                        Text("\(Int(usage.remainingPercent.rounded()))% left")
                            .font(.title3.bold().monospacedDigit())
                    }

                    ProgressView(value: usage.remainingPercent, total: 100)
                        .tint(.green)
                        .accessibilityLabel("Weekly limit remaining")

                    HStack {
                        Text(
                            "Resets "
                                + usage.resetAt.formatted(
                                    .dateTime.weekday(.wide).hour().minute(),
                                ),
                        )

                        Spacer()

                        if abs(pacing) < 0.5 {
                            Text("On pace")
                        } else {
                            Text("\(Int(abs(pacing).rounded()))% \(pacing > 0 ? "ahead" : "behind")")
                                .foregroundStyle(pacing > 0 ? .green : .orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        "Day \(usage.currentDay(at: now)) target: "
                            + "\(Int(target.rounded()))% used · "
                            + "\(Int(usage.usedPercent.rounded()))% used",
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Picker("Weekly pacing", selection: self.$pacing) {
                        ForEach(WeeklyUsage.Pacing.allCases, id: \.self) { pacing in
                            switch pacing {
                                case .linear:
                                    Text("Linear").tag(pacing)

                                case .logarithmic:
                                    Text("Logarithmic").tag(pacing)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                    .help("Weekly pacing")
                }

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
            } else if self.store.isRefreshing {
                HStack {
                    ProgressView()
                    Text("Loading OpenAI usage…")
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.title2)

                    Text("Usage unavailable")
                        .font(.headline)

                    Text(self.store.errorMessage ?? "Run `codex login`, then refresh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }

            if let errorMessage = store.errorMessage, store.snapshot != nil {
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
