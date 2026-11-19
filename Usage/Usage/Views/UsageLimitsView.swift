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

    /// One usage window's remaining percent, remaining bar with pace marker, reset time, and pace.
    private struct WindowSection: View {
        let remainingPercent: Double
        let resetAt: Date
        let systemImage: String
        let target: Double
        let title: String
        let usedPercent: Double

        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                Label(self.title, systemImage: self.systemImage)
                    .font(.headline)

                Spacer()

                Text("\(Int(self.remainingPercent.rounded()))% left")
                    .font(.title3.bold().monospacedDigit())
            }

            ProgressView(value: self.remainingPercent, total: 100)
                .tint(.green)
                .overlay {
                    PaceMarker(target: self.target)
                }
                .accessibilityLabel("\(self.title) remaining")

            HStack {
                Text("Resets " + self.resetAt.formatted(.dateTime.weekday(.wide).hour().minute()))

                Spacer()

                PaceText(target: self.target, usedPercent: self.usedPercent)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    let fableWeeklyUsage: WeeklyUsage?
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
                    VStack(alignment: .leading, spacing: 8) {
                        WindowSection(
                            remainingPercent: fiveHourUsage.remainingPercent,
                            resetAt: fiveHourUsage.resetAt,
                            systemImage: "clock",
                            target: self.pacing.targetUsedPercent(
                                resetAt: fiveHourUsage.resetAt,
                                duration: FiveHourUsage.duration,
                                at: now,
                            ),
                            title: "5-hour limit",
                            usedPercent: fiveHourUsage.usedPercent,
                        )
                    }

                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    WindowSection(
                        remainingPercent: usage.remainingPercent,
                        resetAt: usage.resetAt,
                        systemImage: "calendar.badge.clock",
                        target: target,
                        title: "Weekly limit",
                        usedPercent: usage.usedPercent,
                    )

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

                if let fableWeeklyUsage = self.fableWeeklyUsage {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        WindowSection(
                            remainingPercent: fableWeeklyUsage.remainingPercent,
                            resetAt: fableWeeklyUsage.resetAt,
                            systemImage: "calendar.badge.clock",
                            target: self.pacing.targetUsedPercent(
                                resetAt: fableWeeklyUsage.resetAt,
                                duration: WeeklyUsage.duration,
                                at: now,
                            ),
                            title: "Fable weekly limit",
                            usedPercent: fableWeeklyUsage.usedPercent,
                        )
                    }
                }
            }
        }
    }
}
