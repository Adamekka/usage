//
//  MenuBarLabel.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import AppKit
import SwiftUI

struct MenuBarLabel: View {
    /// One usage window as a remaining bar with a pace marker, followed by its remaining percent and reset time.
    private struct WindowRow: View {
        private static let barWidth: CGFloat = 20

        let accessibilityResetText: String
        let name: String
        let remainingPercent: Double
        let resetText: String
        let targetUsedPercent: Double

        /// A window counts as exhausted when this rounds to 0, so the menu bar never drops a percent it would show as
        /// usable.
        var displayedRemainingPercent: Int {
            .init(self.remainingPercent.rounded())
        }

        /// Spells out what the compact row abbreviates, including the pace marker the bar shows.
        var accessibilityText: String {
            let remainingText: String = self.displayedRemainingPercent > 0
                ? "\(self.displayedRemainingPercent)% left"
                : "limit reached"

            return "\(self.name) \(remainingText), resets \(self.accessibilityResetText), "
                + "target \(Int((100 - self.targetUsedPercent).rounded()))% left"
        }

        var body: some View {
            let markerX: CGFloat = Self.barWidth * (100 - self.targetUsedPercent) / 100

            HStack(spacing: 3) {
                // Template images carry only alpha, so the track is a faint fill and the remaining usage a solid one.
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .frame(height: 4)
                        .opacity(0.35)

                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: Self.barWidth * self.remainingPercent / 100, height: 4)

                    // The cleared gap separates the marker from the fill on both sides.
                    Rectangle()
                        .frame(width: 3, height: 4)
                        .offset(x: markerX - 1.5)
                        .blendMode(.destinationOut)

                    Rectangle()
                        .frame(width: 1, height: 8)
                        .offset(x: markerX - 0.5)
                }
                .frame(width: Self.barWidth, height: 8)
                .compositingGroup()

                // An exhausted window drops its percent but keeps its reset time, since that is when usage becomes
                // available again.
                Text(
                    self.displayedRemainingPercent > 0
                        ? "\(self.displayedRemainingPercent)% \(self.resetText)"
                        : self.resetText,
                )
            }
        }
    }

    let store: UsageStore

    @AppStorage(Pacing.storageKey) private var pacing: Pacing = .defaultValue
    /// The pace markers depend on the current time, which SwiftUI does not observe, so this is advanced periodically to
    /// redraw instead of only when usage changes. A TimelineView would be the usual tool, but MenuBarExtra drops a
    /// label wrapped in one.
    @State private var now: Date = .now

    var body: some View {
        let status: String = self.store.isRefreshing ? "Loading" : "Unavailable"

        func rows(fiveHourUsage: FiveHourUsage?, weeklyUsage: WeeklyUsage) -> [WindowRow] {
            let weeklyRow: WindowRow = .init(
                accessibilityResetText: weeklyUsage.resetAt.formatted(.dateTime.weekday(.wide)),
                name: "weekly",
                remainingPercent: weeklyUsage.remainingPercent,
                resetText: weeklyUsage.resetAt.formatted(.dateTime.weekday(.abbreviated)),
                targetUsedPercent: self.pacing.targetUsedPercent(
                    resetAt: weeklyUsage.resetAt,
                    duration: WeeklyUsage.duration,
                    at: self.now,
                ),
            )

            // The five-hour window cannot be used until the weekly window resets, so only the weekly row matters.
            guard weeklyRow.displayedRemainingPercent > 0, let fiveHourUsage else {
                return [weeklyRow]
            }

            let fiveHourRow: WindowRow = .init(
                accessibilityResetText: fiveHourUsage.resetAt.formatted(.dateTime.hour().minute()),
                name: "5-hour",
                remainingPercent: fiveHourUsage.remainingPercent,
                // The reset is at most five hours away, so the period is unambiguous and omitted to save width.
                resetText: fiveHourUsage.resetAt.formatted(
                    .dateTime.hour(.defaultDigits(amPM: .omitted)).minute(),
                ),
                targetUsedPercent: self.pacing.targetUsedPercent(
                    resetAt: fiveHourUsage.resetAt,
                    duration: FiveHourUsage.duration,
                    at: self.now,
                ),
            )

            return [fiveHourRow, weeklyRow]
        }

        let openAIRows: [WindowRow]? = self.store.openAISnapshot.map {
            rows(fiveHourUsage: $0.fiveHourUsage, weeklyUsage: $0.weeklyUsage)
        }
        let claudeRows: [WindowRow]? = self.store.claudeSnapshot.map {
            rows(fiveHourUsage: $0.fiveHourUsage, weeklyUsage: $0.weeklyUsage)
        }

        // Stacking the five-hour row above the weekly row roughly halves the label's width, which leaves room for
        // the bars within the menu bar's height.
        func provider(logo: ImageResource, rows: [WindowRow]?) -> some View {
            HStack(spacing: 3) {
                Image(logo)

                if let rows {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rows.indices, id: \.self) { index in
                            rows[index]
                                .frame(height: 11)
                        }
                    }
                    // A lone weekly row sits in the weekly slot so it lines up with the other provider's weekly row.
                    .frame(height: 22, alignment: .bottom)
                } else {
                    Text(status)
                }
            }
        }

        // MenuBarExtra flattens its label to one image and plain text, dropping additional and embedded images, so
        // the whole label is rendered into one template image that the menu bar tints for its appearance.
        let renderer: ImageRenderer = .init(
            content: HStack(spacing: 8) {
                provider(logo: .openAI, rows: openAIRows)
                provider(logo: .claude, rows: claudeRows)
            }
            .font(.system(size: 9.5, weight: .medium).monospacedDigit())
            .foregroundStyle(.black),
        )
        renderer.scale = 2

        guard let image = renderer.nsImage else {
            preconditionFailure("The menu bar label could not be rendered")
        }

        image.isTemplate = true

        let openAIText: String = openAIRows?.map(\.accessibilityText).joined(separator: ", ") ?? status
        let claudeText: String = claudeRows?.map(\.accessibilityText).joined(separator: ", ") ?? status

        return Image(nsImage: image)
            .accessibilityLabel("Codex: \(openAIText). Claude: \(claudeText).")
            .task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(60))
                    } catch {
                        return
                    }

                    self.now = .now
                }
            }
    }
}
