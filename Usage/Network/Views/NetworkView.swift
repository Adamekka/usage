//
//  NetworkView.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

struct NetworkView: View {
    private enum Direction: CaseIterable {
        case download
        case upload
    }

    @State private var store: NetworkStore = .init()
    @State private var retry: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            switch self.store.state {
                case .loading:
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Measuring network activity…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)

                case let .live(applications):
                    if applications.isEmpty {
                        Text("No network activity")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        HStack {
                            Text("App")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Download")
                                .frame(width: 80, alignment: .trailing)
                            Text("Upload")
                                .frame(width: 80, alignment: .trailing)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(applications) { app in
                                    HStack(spacing: 8) {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                                .accessibilityHidden(true)
                                        } else {
                                            Image(systemName: "gearshape")
                                                .frame(width: 20, height: 20)
                                                .foregroundStyle(.secondary)
                                                .accessibilityHidden(true)
                                        }

                                        Text(app.name)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .help(app.name)

                                        ForEach(Direction.allCases, id: \.self) { direction in
                                            let (speed, label): (Double, String) = switch direction {
                                                case .download:
                                                    (app.download, "Download")

                                                case .upload:
                                                    (app.upload, "Upload")
                                            }
                                            let rate: String = Int64(speed.rounded()).formatted(
                                                .byteCount(style: .decimal, spellsOutZero: false),
                                            ) + "/s"
                                            Text(rate)
                                                .monospacedDigit()
                                                .frame(width: 80, alignment: .trailing)
                                                .accessibilityLabel("\(label), \(rate)")
                                        }
                                    }
                                    .font(.callout)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(height: 260)
                    }

                case let .failed(message):
                    VStack(spacing: 12) {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            self.retry += 1
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .frame(height: 300)
        .task(id: self.retry) {
            await self.store.monitor()
        }
    }
}
