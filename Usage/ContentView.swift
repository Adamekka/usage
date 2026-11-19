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

    private enum Tab: CaseIterable {
        case codex
        case claude
        case network
    }

    @State private var tab: Tab = .codex

    var body: some View {
        let version: String = {
            guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
                preconditionFailure("CFBundleShortVersionString is missing from the app bundle")
            }

            return version
        }()

        VStack(alignment: .leading, spacing: 14) {
            Picker("Tab", selection: self.$tab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    switch tab {
                        case .codex:
                            Text("Codex").tag(tab)

                        case .claude:
                            Text("Claude").tag(tab)

                        case .network:
                            Text("Network").tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch self.tab {
                case .codex:
                    OpenAIUsageView(store: self.store)

                case .claude:
                    UsageStatusView(
                        errorMessage: self.store.claudeErrorMessage,
                        loadingText: "Loading Claude usage…",
                        signInHint: "Run `claude`, then refresh.",
                        snapshot: self.store.claudeSnapshot,
                        store: self.store,
                    ) { snapshot in
                        UsageLimitsView(
                            fableWeeklyUsage: snapshot.fableWeeklyUsage,
                            fiveHourUsage: snapshot.fiveHourUsage,
                            weeklyUsage: snapshot.weeklyUsage,
                        )
                    }

                case .network:
                    NetworkView()
            }

            Divider()

            HStack {
                LaunchAtLogin.Toggle()
                    .toggleStyle(.checkbox)

                Spacer()

                Text("v\(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if self.tab == .codex || self.tab == .claude {
                    Button {
                        Task {
                            await self.store.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(self.store.isRefreshing)
                    .help("Refresh usage")
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
