//
//  UsageStore.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation
import Observation

@Observable
final class UsageStore {
    private(set) var claudeErrorMessage: String? = nil
    private(set) var claudeSnapshot: ClaudeSnapshot? = nil
    private(set) var isRefreshing: Bool = false
    private(set) var openAIErrorMessage: String? = nil
    private(set) var openAISnapshot: OpenAISnapshot? = nil

    func refresh() async {
        guard !self.isRefreshing else {
            return
        }

        self.isRefreshing = true
        defer { self.isRefreshing = false }

        async let openAIResult: Result<OpenAISnapshot, any Error> = .init { try await OpenAIClient().fetchSnapshot() }
        async let claudeResult: Result<ClaudeSnapshot, any Error> = .init { try await ClaudeClient().fetchSnapshot() }

        switch await openAIResult {
            case let .success(snapshot):
                self.openAISnapshot = snapshot
                self.openAIErrorMessage = nil

            case let .failure(error):
                self.openAIErrorMessage = error.localizedDescription
        }

        switch await claudeResult {
            case let .success(snapshot):
                self.claudeSnapshot = snapshot
                self.claudeErrorMessage = nil

            case let .failure(error):
                self.claudeErrorMessage = error.localizedDescription
        }
    }
}
