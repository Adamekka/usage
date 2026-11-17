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

        // An exhausted window drops its percent but keeps its reset time, since that is when usage becomes available
        // again. A window counts as exhausted when its displayed remaining percent rounds to 0, so the menu bar never
        // drops a percent it would show as usable.
        func usageText(fiveHourUsage: FiveHourUsage?, weeklyUsage: WeeklyUsage) -> String {
            let weeklyRemainingPercent: Int = .init(weeklyUsage.remainingPercent.rounded())
            let weeklyResetText: String = weeklyUsage.resetAt.formatted(.dateTime.weekday(.abbreviated))

            // The five-hour window cannot be used until the weekly window resets, so only the weekly reset matters.
            guard weeklyRemainingPercent > 0 else {
                return weeklyResetText
            }

            let weeklyText: String = "\(weeklyRemainingPercent)% · \(weeklyResetText)"

            guard let fiveHourUsage else {
                return weeklyText
            }

            let fiveHourRemainingPercent: Int = .init(fiveHourUsage.remainingPercent.rounded())
            let fiveHourResetText: String = fiveHourUsage.resetAt.formatted(.dateTime.hour().minute())
            let fiveHourText: String = fiveHourRemainingPercent > 0
                ? "\(fiveHourRemainingPercent)% · \(fiveHourResetText)"
                : fiveHourResetText

            return "\(fiveHourText) | \(weeklyText)"
        }

        let openAIText: String = self.store.openAISnapshot.map {
            usageText(fiveHourUsage: $0.fiveHourUsage, weeklyUsage: $0.weeklyUsage)
        } ?? status
        let claudeText: String = self.store.claudeSnapshot.map {
            usageText(fiveHourUsage: $0.fiveHourUsage, weeklyUsage: $0.weeklyUsage)
        } ?? status

        // MenuBarExtra flattens its label to one image and plain text, dropping additional and embedded images, so the
        // whole label is rendered into one template image that the menu bar tints for its appearance.
        let renderer: ImageRenderer = .init(
            content: HStack(spacing: 4) {
                Image(.openAI)
                Text(openAIText)

                Image(.claude)
                    .padding(.leading, 6)
                Text(claudeText)
            }
            .font(Font(NSFont.menuBarFont(ofSize: 0)))
            .foregroundStyle(.black),
        )
        renderer.scale = 2

        guard let image = renderer.nsImage else {
            preconditionFailure("The menu bar label could not be rendered")
        }

        image.isTemplate = true

        return Image(nsImage: image)
            .accessibilityLabel("Codex \(openAIText), Claude \(claudeText)")
    }
}
