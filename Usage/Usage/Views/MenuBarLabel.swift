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

        func usageText(fiveHourUsage: FiveHourUsage?, weeklyUsage: WeeklyUsage) -> String {
            let weeklyText: String = "\(Int(weeklyUsage.remainingPercent.rounded()))% · "
                + weeklyUsage.resetAt.formatted(.dateTime.weekday(.abbreviated))

            guard let fiveHourUsage else {
                return weeklyText
            }

            return "\(Int(fiveHourUsage.remainingPercent.rounded()))% · "
                + fiveHourUsage.resetAt.formatted(.dateTime.hour().minute())
                + " | "
                + weeklyText
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
