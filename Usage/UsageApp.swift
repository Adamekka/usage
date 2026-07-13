//
//  UsageApp.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import SwiftUI

@main
struct UsageApp: App {
    @State private var store: UsageStore = .init()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: self.store)
        } label: {
            MenuBarLabel(store: self.store)
                .task {
                    await self.store.refresh()

                    while !Task.isCancelled {
                        do {
                            try await Task.sleep(for: .seconds(300))
                        } catch {
                            return
                        }

                        await self.store.refresh()
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}
