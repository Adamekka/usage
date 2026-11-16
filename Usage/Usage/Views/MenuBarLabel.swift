//
//  MenuBarLabel.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let store: UsageStore

    var body: some View {
        let status: String = self.store.isRefreshing ? "Loading" : "Unavailable"

        // Returns nil when the weekly window is exhausted, which hides the whole provider. A window counts as exhausted
        // when its displayed remaining percent rounds to 0, so the menu bar never hides a window it would show as
        // usable.
        func usageText(fiveHourUsage: FiveHourUsage?, weeklyUsage: WeeklyUsage) -> String? {
            let weeklyRemainingPercent: Int = .init(weeklyUsage.remainingPercent.rounded())

            guard weeklyRemainingPercent > 0 else {
                return nil
            }

            let weeklyText: String = "\(weeklyRemainingPercent)% · "
                + weeklyUsage.resetAt.formatted(.dateTime.weekday(.abbreviated))

            guard let fiveHourUsage else {
                return weeklyText
            }

            let fiveHourRemainingPercent: Int = .init(fiveHourUsage.remainingPercent.rounded())

            guard fiveHourRemainingPercent > 0 else {
                return weeklyText
            }

            return "\(fiveHourRemainingPercent)% · "
                + fiveHourUsage.resetAt.formatted(.dateTime.hour().minute())
                + " | "
                + weeklyText
        }

        let openAIText: String? = if let snapshot = self.store.openAISnapshot {
            usageText(fiveHourUsage: snapshot.fiveHourUsage, weeklyUsage: snapshot.weeklyUsage)
        } else {
            status
        }
        let claudeText: String? = if let snapshot = self.store.claudeSnapshot {
            usageText(fiveHourUsage: snapshot.fiveHourUsage, weeklyUsage: snapshot.weeklyUsage)
        } else {
            status
        }
        let isEveryProviderHidden: Bool = openAIText == nil && claudeText == nil

        // MenuBarExtra flattens its label to one image and plain text, dropping additional and embedded images, so the
        // whole label is rendered into one template image that the menu bar tints for its appearance.
        let renderer: ImageRenderer = .init(
            content: HStack(spacing: 4) {
                // An empty label would leave nothing to click, so the app name stands in when every provider is
                // exhausted.
                if isEveryProviderHidden {
                    Text("Usage")
                }

                if let openAIText {
                    Image(.openAI)
                    Text(openAIText)
                }

                if let claudeText {
                    Image(.claude)
                        .padding(.leading, openAIText == nil ? 0 : 6)
                    Text(claudeText)
                }
            }
            .font(Font(NSFont.menuBarFont(ofSize: 0)))
            .foregroundStyle(.black),
        )
        renderer.scale = 2

        guard let image = renderer.nsImage else {
            preconditionFailure("The menu bar label could not be rendered")
        }

        image.isTemplate = true

        let accessibilityLabel: String = isEveryProviderHidden
            ? "Codex and Claude limits reached"
            : [
                openAIText.map { "Codex \($0)" },
                claudeText.map { "Claude \($0)" },
            ]
            .compactMap(\.self)
            .joined(separator: ", ")

        return Image(nsImage: image)
            .accessibilityLabel(accessibilityLabel)
    }
}
