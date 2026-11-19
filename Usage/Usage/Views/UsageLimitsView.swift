//
//  UsageLimitsView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct UsageLimitsView: View {
    /// Marks the remaining usage the pacing target expects at this moment.
    private struct PaceMarker: View {
        let target: Double

        var body: some View {
            GeometryReader { proxy in
                // The background-colored outline separates it from both the fill and the empty track.
                Capsule()
                    .fill(Color(nsColor: .textColor))
                    .frame(width: 3, height: 16)
                    .padding(2)
                    .background(.background, in: Capsule())
                    .position(x: proxy.size.width * (100 - self.target) / 100, y: proxy.size.height / 2)
            }
        }
    }

    private struct PaceText: View {
        let target: Double
        let usedPercent: Double

        var body: some View {
            let pacing: Double = self.usedPercent - self.target

            if abs(pacing) < 0.5 {
                Text("On pace")
            } else {
                Text("\(Int(abs(pacing).rounded()))% \(pacing > 0 ? "ahead" : "behind")")
                    .foregroundStyle(pacing > 0 ? .green : .orange)
            }
        }
    }

    let fiveHourUsage: FiveHourUsage?
    let weeklyUsage: WeeklyUsage

    @AppStorage(Pacing.storageKey) private var pacing: Pacing = .defaultValue

    var body: some View {
        // The pacing target and marker depend on the current time, which SwiftUI does not observe, so redraw
        // periodically instead of only when usage changes.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 14) {
                let usage: WeeklyUsage = self.weeklyUsage
                let now: Date = context.date
                let target: Double = self.pacing.targetUsedPercent(
                    resetAt: usage.resetAt,
                    duration: WeeklyUsage.duration,
                    at: now,
                )

                if let fiveHourUsage = self.fiveHourUsage {
                    let fiveHourTarget: Double = self.pacing.targetUsedPercent(
                        resetAt: fiveHourUsage.resetAt,
                        duration: FiveHourUsage.duration,
                        at: now,
                    )

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
                            .overlay {
                                PaceMarker(target: fiveHourTarget)
                            }
                            .accessibilityLabel("5-hour limit remaining")

                        HStack {
                            Text(
                                "Resets "
                                    + fiveHourUsage.resetAt.formatted(
                                        .dateTime.weekday(.wide).hour().minute(),
                                    ),
                            )

                            Spacer()

                            PaceText(target: fiveHourTarget, usedPercent: fiveHourUsage.usedPercent)
                        }
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
                        .overlay {
                            PaceMarker(target: target)
                        }
                        .accessibilityLabel("Weekly limit remaining")

                    HStack {
                        Text(
                            "Resets "
                                + usage.resetAt.formatted(
                                    .dateTime.weekday(.wide).hour().minute(),
                                ),
                        )

                        Spacer()

                        PaceText(target: target, usedPercent: usage.usedPercent)
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

                    Picker("Pacing", selection: self.$pacing) {
                        ForEach(Pacing.allCases, id: \.self) { pacing in
                            switch pacing {
                                case .linear:
                                    Text("Linear").tag(pacing)

                                case .logarithmic:
                                    Text("Logarithmic").tag(pacing)

                                case .exponential:
                                    Text("Exponential").tag(pacing)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                    .help("Pacing")
                }
            }
        }
    }
}
