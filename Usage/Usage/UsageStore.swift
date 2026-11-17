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
    private(set) var isClaudeAccessLost: Bool = false
    private(set) var isOpenAIAccessLost: Bool = false
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
                self.isOpenAIAccessLost = false

            case let .failure(error):
                self.openAIErrorMessage = error.localizedDescription
                // Other errors, such as network failures, are temporary.
                self.isOpenAIAccessLost = (error as? OpenAIError)?.isAccessLost ?? false
        }

        switch await claudeResult {
            case let .success(snapshot):
                self.claudeSnapshot = snapshot
                self.claudeErrorMessage = nil
                self.isClaudeAccessLost = false

            case let .failure(error):
                self.claudeErrorMessage = error.localizedDescription
                // Other errors, such as network failures, are temporary.
                self.isClaudeAccessLost = (error as? ClaudeError)?.isAccessLost ?? false
        }
    }
}
