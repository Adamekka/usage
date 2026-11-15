//
//  UsageLimitsView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct UsageLimitsView: View {
    let fiveHourUsage: FiveHourUsage?
    let weeklyUsage: WeeklyUsage

    @AppStorage("weeklyPacing") private var pacing: WeeklyUsage.Pacing = .linear

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let usage: WeeklyUsage = self.weeklyUsage
            let now: Date = .now
            let target: Double = usage.targetUsedPercent(at: now, pacing: self.pacing)
            let pacing: Double = usage.usedPercent - target

            if let fiveHourUsage = self.fiveHourUsage {
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
        }
    }
}
