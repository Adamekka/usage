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
        case openAI
        case network
    }

    @State private var tab: Tab = .openAI

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
                        case .openAI:
                            Text("OpenAI").tag(tab)

                        case .network:
                            Text("Network").tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch self.tab {
                case .openAI:
                    OpenAIUsageView(store: self.store)

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

                if self.tab == .openAI {
                    Button {
                        Task {
                            await self.store.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(self.store.isRefreshing)
                    .help("Refresh OpenAI usage")
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
