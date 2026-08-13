//
//  ContentView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import AppKit
import LaunchAtLogin
import SwiftUI

struct ContentView: View {
    let store: UsageStore

    var body: some View {
        let version: String = {
            guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
                preconditionFailure("CFBundleShortVersionString is missing from the app bundle")
            }

            return version
        }()

        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = store.snapshot {
                let usage: WeeklyUsage = snapshot.weeklyUsage
                let target: Double = usage.targetUsedPercent(at: .now)
                let pacing: Double = usage.usedPercent - target

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
                        "Day \(usage.currentDay(at: .now)) target: "
                            + "\(Int(target.rounded()))% used · "
                            + "\(Int(usage.usedPercent.rounded()))% used",
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Divider()

            HStack {
                LaunchAtLogin.Toggle()
                    .toggleStyle(.checkbox)

                Spacer()

                Text("v\(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await self.store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(self.store.isRefreshing)
                .help("Refresh")

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            Task { await self.store.refresh() }
        }
    }
}
