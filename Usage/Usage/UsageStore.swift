//
//  UsageStore.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation
import Observation

@Observable
final class UsageStore {
    private(set) var errorMessage: String? = nil
    private(set) var isRefreshing: Bool = false
    private(set) var snapshot: OpenAISnapshot? = nil

    func refresh() async {
        guard !self.isRefreshing else {
            return
        }

        self.isRefreshing = true
        defer { self.isRefreshing = false }

        do {
            self.snapshot = try await OpenAIClient().fetchSnapshot()
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
